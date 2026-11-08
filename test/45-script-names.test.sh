#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

module="$PONT_MODULES_HOME/script_names"
out="$PONT_TARGET/script_names"
stubs="$PONT_TARGET/script_names_stubs"
trap 'rm -rf "$module"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module" "$out" "$stubs"
mkdir -p "$module" "$out" "$stubs"

cat >"$stubs/sudo" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$out/sudo-calls"
EOF
chmod +x "$stubs/sudo"
PATH="$stubs:$PATH"
export PATH

scripts='0.user.sh
01.user-local.sh
1.user.fallback.sh
e.user.sh
e0.user.sh
env.user.sh
i.user.sh
init.user.sh
u.user.sh
u0.user.sh
update.user.sh
r.user.sh
r1.user.sh
remove.user.sh
u.user.ps1'
not_scripts_with_warning='0.user.pacman.bak
0.user.sh~
update.user.sh.orig
i.local.sh'
not_scripts='eslint.config.ts
e.config.ts
env.d.ts
update.test.ts
index.d.ts
readme.v2.md
restore.user.sh
notes.md
1.md
u.txt
u.user
foo.user.bak
extra.local.sh'
# shellcheck disable=SC2016
windows_scripts='0.user.ps1
1.user.$windows.ps1'

for name in $scripts $not_scripts_with_warning $not_scripts \
	$windows_scripts; do
	cat >"$module/$name" <<EOF
#!/bin/sh
: >"$out/$name"
EOF
	chmod +x "$module/$name"
done
for name in 2.root.sh 3.sudo.sh 4.root.pacman.bak; do
	cp "$module/0.user.sh" "$module/$name"
done
echo true >"$module/0.user.sh.condition"

./pont.sh -fx script_names >/dev/null 2>"$out/log"
$COVERAGE ./pont.sh -q -fu script_names
$COVERAGE ./pont.sh -q -rr script_names
sync

for name in $scripts; do
	[ -e "$out/$name" ] || fail "Script did not run: $name"
done
for name in $not_scripts_with_warning $not_scripts; do
	[ ! -e "$out/$name" ] || fail "Not a script, but ran: $name"
done
for name in $windows_scripts; do
	[ ! -e "$out/$name" ] || fail "PowerShell install script ran: $name"
done
grep -q '/2\.root\.sh$' "$out/sudo-calls" ||
	fail "Root script did not call sudo"
grep -q '/3\.sudo\.sh$' "$out/sudo-calls" ||
	fail "Sudo script did not call sudo"
! grep -q '4\.root\.pacman\.bak' "$out/sudo-calls" ||
	fail "Backup of a root script called sudo"

sed 's/\x1b\[[0-9;]*m//g' "$out/log" >"$out/plain-log"
warned() {
	grep -qFx "[ Warning ]: Not a script name, not run: $module/$1" \
		"$out/plain-log"
}
for name in $not_scripts_with_warning 4.root.pacman.bak; do
	warned "$name" || fail "No warning for $name"
done
for name in $scripts $not_scripts $windows_scripts 2.root.sh 3.sudo.sh \
	0.user.sh.condition; do
	! warned "$name" || fail "Warning for $name"
done
