#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# A condition with a syntax error or an exit does not stop pont

modules="condition_error_broken condition_error_exit condition_error_after"
modules="$modules condition_error_installed condition_error_entries"
modules="$modules condition_error_brace condition_error_name"
installed="$PONT_MODULES_HOME/condition_error_installed"
link="$PONT_TARGET/condition_error_file"
cleanup() {
	for module in $modules; do
		rm -rf "${PONT_MODULES_HOME:?}/$module"
	done
}
trap cleanup EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
cleanup
for module in $modules; do
	mkdir -p "$PONT_MODULES_HOME/$module"
	for script in 1 u r; do
		cat >"$PONT_MODULES_HOME/$module/$script.user.sh" <<EOF
#!/bin/sh
: >"\$PONT_TARGET/$module.$script.ran"
EOF
		chmod +x "$PONT_MODULES_HOME/$module/$script.user.sh"
	done
done
printf '%s\n' 'if true' >"$PONT_MODULES_HOME/condition_error_broken/.condition"
printf '%s\n' 'exit 1' >"$PONT_MODULES_HOME/condition_error_exit/.condition"
cat >"$PONT_MODULES_HOME/condition_error_brace/.condition" <<'EOF'
false; }; { : >"$PONT_TARGET/condition_error_brace.mark"
EOF
cat >"$PONT_MODULES_HOME/condition_error_name/.condition" <<'EOF'
[ "$1" = condition_error_name ]
EOF

output=$(./pont.sh -fx condition_error_broken condition_error_exit \
	condition_error_brace condition_error_name condition_error_after 2>&1) ||
	fail "pont failed: $output"
[ -e "$PONT_TARGET/condition_error_after.1.ran" ] ||
	fail "pont stopped at a module condition: $output"
[ ! -e "$PONT_TARGET/condition_error_broken.1.ran" ] ||
	fail "A module whose condition has a syntax error ran"
[ ! -e "$PONT_TARGET/condition_error_exit.1.ran" ] ||
	fail "A module whose condition exits with 1 ran"
[ ! -e "$PONT_TARGET/condition_error_brace.mark" ] ||
	fail "The syntax check ran a part of a condition"
[ -e "$PONT_TARGET/condition_error_name.1.ran" ] ||
	fail "A .condition did not get the module name as \$1: $output"
expected='Syntax error in the condition of condition_error_broken.'
printf '%s\n' "$output" | grep -qF "$expected Skipping. if true" ||
	fail "-x did not log the syntax error: $output"
expected='Syntax error in the condition of condition_error_brace.'
printf '%s\n' "$output" | grep -qF "$expected" ||
	fail "-x did not log the syntax error of the braces: $output"
printf '%s\n' "$output" |
	grep -qF 'Condition on condition_error_exit failed. Skipping. exit 1' ||
	fail "-x did not log the failed condition: $output"

mkdir -p "$installed/.condition_error_installed"
echo package >"$installed/.condition_error_installed/condition_error_file"
$COVERAGE ./pont.sh -q -fx condition_error_installed
[ -L "$link" ] && [ -e "$installed/.tarhash" ] ||
	fail "The module did not install"
printf '%s\n' 'if true' >"$installed/.condition"
output=$(./pont.sh -u condition_error_installed 2>&1) ||
	fail "-u failed: $output"
[ ! -e "$PONT_TARGET/condition_error_installed.u.ran" ] ||
	fail "-u ran an update script of a module with a syntax error"
printf '%s\n' "$output" |
	grep -qF 'Syntax error in the condition of condition_error_installed.' ||
	fail "-u did not log the syntax error: $output"
output=$(./pont.sh -rr condition_error_installed 2>&1) ||
	fail "-rr failed: $output"
sync
[ -L "$link" ] || fail "-r removed the links of a module with a syntax error"
[ -e "$installed/.tarhash" ] ||
	fail "-r removed the hash of a module with a syntax error"
[ ! -e "$PONT_TARGET/condition_error_installed.r.ran" ] ||
	fail "-rr ran a remove script of a module with a syntax error"
printf '%s\n' "$output" |
	grep -qF 'Syntax error in the condition of condition_error_installed.' ||
	fail "-r did not log the syntax error: $output"

cat >"$PONT_MODULES_HOME/condition_error_entries/.dependencies" <<'EOF'
condition_error_missing ? if true
condition_error_after ? exit 0
condition_error_name ? [ -n "$1" ]
EOF
$COVERAGE ./pont.sh -eL condition_error_entries >/dev/null 2>&1
result=$(./pont.sh -eL condition_error_entries 2>/dev/null) ||
	fail "The expansion failed: $result"
[ "$result" = "condition_error_after
condition_error_name
condition_error_entries" ] ||
	fail "The expansion of entries with conditions selected: $result"
output=$(./pont.sh -eL condition_error_entries 2>&1 >/dev/null)
expected='Syntax error in the condition of entry condition_error_missing.'
printf '%s\n' "$output" | grep -qF "$expected Skipping. if true" ||
	fail "The expansion did not log the syntax error: $output"
