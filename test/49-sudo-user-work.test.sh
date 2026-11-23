#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Under sudo, pont runs the user work and its conditions as SUDO_USER, with the
# home of that user. The condition of a root step runs in pont. A stub sudo
# records its calls, sets the SUDO_ variables as sudo does and runs the command
# as the user who runs the test. Test 23 runs a real sudo.

module="$PONT_MODULES_HOME/sudo_user_work"
dependency="$PONT_MODULES_HOME/sudo_user_work_dependency"
out="$PONT_TARGET/sudo_user_work"
stubs="$PONT_TARGET/sudo_user_work_stubs"
link="$PONT_TARGET/sudo_user_work_file"
preset="$PONT_PRESETS_HOME/sudo_user_work_preset.preset"
failing="$PONT_MODULES_HOME/sudo_user_work_failing"
trap 'rm -rf "$module" "$dependency" "$out" "$stubs" "$link" "$preset" \
	"$failing"_user "$failing"_root' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module" "$dependency" "$out" "$stubs" "$link" "$preset" \
	"$failing"_user "$failing"_root
mkdir -p "$module" "$dependency" "$out" "$stubs"

cat >"$stubs/sudo" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then
	echo --version >>"$out/sudo-versions"
	echo 'Sudo version 1.9.17'
	exit 0
fi
printf '%s\n' "\$*" >>"$out/sudo-calls"
while [ "\$#" -gt 0 ]; do
	case \$1 in
		-u) shift 2 ;;
		-*) shift ;;
		*) break ;;
	esac
done
case \$1 in
	/* | =*) ;;
	*=*)
		printf 'sudo read %s as a variable\\n' "\$1" >>"$out/sudo-variables"
		exit 1
		;;
esac
SUDO_USER=root SUDO_UID=0 SUDO_GID=0 exec "\$@"
EOF
chmod +x "$stubs/sudo"
PATH="$stubs:$PATH"
export PATH

user=$(id -un)
uid=$(id -u)
gid=$(id -g)
user_home=$(getent passwd "$user" | cut -d: -f6)

# Prints code that writes the HOME and SUDO_ variables that it sees to $out/$1
identity() {
	# shellcheck disable=SC2016
	printf 'printf "%%s\\n" "$HOME:$SUDO_USER:$SUDO_UID:$SUDO_GID" >"$PONT_TARGET/sudo_user_work/%s"' \
		"$1"
}

identity module_condition >"$module/.condition"
printf 'sudo_user_work_dependency ? %s\n' "$(identity entry_condition)" \
	>"$module/.dependencies"
identity step_condition >"$module/1.user.sh.condition"
printf '#!/bin/sh\n%s\n' "$(identity step)" >"$module/1.user.sh"
printf 'return 1\nexit 3\n' >"$module/2.user.sh.condition"
printf '#!/bin/sh\n%s\n' "$(identity skipped_step)" >"$module/2.user.sh"
printf '#!/bin/sh\n%s\n' "$(identity equals_step)" \
	>"$module/3.user.fallback.x=y.sh"
identity root_condition >"$module/4.root.sh.condition"
printf '#!/bin/sh\n%s\n' "$(identity root_step)" >"$module/4.root.sh"
printf '#!/bin/sh\n%s\n' "$(identity root_equals_step)" \
	>"$module/5.root.fallback.x=y.sh"
chmod +x "$module/1.user.sh" "$module/2.user.sh" \
	"$module/3.user.fallback.x=y.sh" "$module/4.root.sh" \
	"$module/5.root.fallback.x=y.sh"
mkdir -p "$module/.sudo_user_work" "$module/SUDO_USER_WORK_TARGET.sudo_user_work"
echo package >"$module/.sudo_user_work/sudo_user_work_file"
echo package >"$module/SUDO_USER_WORK_TARGET.sudo_user_work/target_file"
# shellcheck disable=SC2016
printf 'all:\n\tprintf "%%s\\n" "$$HOME" >"$$PONT_TARGET/sudo_user_work/make"\n' \
	>"$dependency/Makefile"

# HOME as sudo sets it for root, which pont must not pass to the user
HOME="$out/root-home" SUDO_USER="$user" SUDO_UID="$uid" SUDO_GID="$gid" \
	SUDO_USER_WORK_TARGET="$out/missing_target" \
	$COVERAGE ./pont.sh -q -ex sudo_user_work

for name in module_condition entry_condition step_condition step \
	equals_step; do
	[ "$(cat "$out/$name" 2>/dev/null)" = "$user_home:$user:$uid:$gid" ] ||
		fail "The $name saw $(cat "$out/$name" 2>/dev/null), not \
$user_home:$user:$uid:$gid"
done
[ "$(cat "$out/root_condition" 2>/dev/null)" = "$out/root-home:$user:$uid:$gid" ] ||
	fail "The root_condition saw $(cat "$out/root_condition" 2>/dev/null), \
not $out/root-home:$user:$uid:$gid"
for name in root_step root_equals_step; do
	[ "$(cat "$out/$name" 2>/dev/null)" = "$out/root-home:$user:$uid:$gid" ] ||
		fail "The $name saw $(cat "$out/$name" 2>/dev/null), not \
$out/root-home:$user:$uid:$gid"
done
[ ! -e "$out/sudo-variables" ] ||
	fail "A sudo call got a path as a variable: $(cat "$out/sudo-variables")"
[ "$(cat "$out/make" 2>/dev/null)" = "$user_home" ] ||
	fail "make saw the HOME $(cat "$out/make" 2>/dev/null), not $user_home"
[ ! -e "$out/skipped_step" ] ||
	fail "The step whose condition file returns 1 ran"
[ -L "$link" ] || fail "The package is not linked"
[ -L "$out/missing_target/target_file" ] ||
	fail "The package with the missing target is not linked"
[ -e "$module/.tarhash" ] || fail "The module got no hash"
[ "$(cat "$out/sudo-versions")" = --version ] ||
	fail "pont read the version of sudo more than once"
! grep -q -F '4.root.sh.condition' "$out/sudo-calls" ||
	fail "The condition of the root step ran through sudo"

# Fails unless a sudo call ran the command $2 as $user with the home of $user
ran_as_user() {
	grep -F -- " sh $user_home $2" "$out/sudo-calls" |
		grep -q -F -- "-u $user " ||
		fail "The $1 did not run as $user with the home of $user:
$(cat "$out/sudo-calls")"
}

condition_shell="env SUDO_USER=$user SUDO_UID=$uid SUDO_GID=$gid /bin/sh -c"
ran_as_user "module condition" \
	"$condition_shell $(identity module_condition) sh sudo_user_work"
ran_as_user "entry condition" "$condition_shell $(identity entry_condition)"
# shellcheck disable=SC2016
ran_as_user "step condition" \
	"$condition_shell . \"\$0\" $module/1.user.sh.condition"
ran_as_user "stow simulation" "stow -n -R"
ran_as_user "unstow" "stow -D"
ran_as_user "stow" "stow -S"
ran_as_user "mkdir of the target" "mkdir -p $out/missing_target"
ran_as_user "hash" "sh -c mkdir -p"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
git init -q "$out/dotfiles"
mkdir "$out/yank"
echo sudo_user_work >"$preset"
HOME="$out/root-home" SUDO_USER="$user" DOTFILES_HOME="$out/dotfiles" \
	$COVERAGE ./pont.sh -q -p -y "$out/yank" +sudo_user_work_preset \
	>"$out/pull-output" 2>&1 ||
	fail "pont -p -y failed: $(cat "$out/pull-output")"
[ -e "$out/yank/sudo_user_work/1.user.sh" ] || fail "-y copied no module"
ran_as_user "git pull" "git -C $out/dotfiles pull"
ran_as_user "submodule update" "git -C $out/dotfiles submodule update --init"
ran_as_user "mkdir of the yank target" "mkdir -p $out/yank"
ran_as_user "copy of the module" "cp -r $module $out/yank/sudo_user_work"
ran_as_user "copy of the preset" \
	"cp $preset $out/yank/sudo_user_work_preset.preset"

for kind in user root; do
	mkdir -p "$failing"_$kind
	printf '#!/bin/sh\nexit 3\n' >"$failing"_$kind/1.$kind.sh
	chmod +x "$failing"_$kind/1.$kind.sh
done
HOME="$out/root-home" SUDO_USER="$user" SUDO_UID="$uid" SUDO_GID="$gid" \
	$COVERAGE ./pont.sh -q -ex sudo_user_work_failing_user \
	sudo_user_work_failing_root || true
for kind in user root; do
	[ ! -e "$failing"_$kind/.tarhash ] ||
		fail "The module with a failing $kind step got a hash"
done
