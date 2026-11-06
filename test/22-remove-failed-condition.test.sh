#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# -r removes an installed module whose condition failed after its install. Its
# remove scripts need the condition, so -rr does not run them. -r skips a
# module that was never installed and whose condition fails.

# Made here, so that the module list of test 09 stays unchanged
module="$PONT_MODULES_HOME/condition_remove"
never_module="$PONT_MODULES_HOME/condition_remove_never"
hash="$module/.tarhash"
link="$PONT_TARGET/condition_remove_file"
marker="$PONT_TARGET/condition_remove_script"
env_marker="$PONT_TARGET/condition_remove_env"
trap 'rm -rf "$module" "$never_module"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module" "$never_module"

mkdir -p "$module/.condition_remove" "$never_module/.condition_remove_never"
echo package >"$module/.condition_remove/condition_remove_file"
printf '#!/bin/sh\ntouch "%s"\n' "$marker" >"$module/r.user.sh"
chmod +x "$module/r.user.sh"

$COVERAGE ./pont.sh -q condition_remove
[ -L "$link" ] && [ -e "$hash" ] ||
	fail "The module did not install"

echo false >"$module/.condition"
./pont.sh -O | grep -qx condition_remove ||
	fail "-O does not list the module before -r"
$COVERAGE ./pont.sh -q -rr condition_remove
sync
[ ! -L "$link" ] || fail "-r kept the links of the module"
[ ! -e "$hash" ] || fail "-r kept the hash of the module"
[ ! -e "$marker" ] ||
	fail "-rr ran a remove script of a module whose condition failed"

# With its condition, -rr runs the remove scripts
rm "$module/.condition"
$COVERAGE ./pont.sh -q condition_remove
$COVERAGE ./pont.sh -q -rr condition_remove
sync
[ -e "$marker" ] || fail "-rr did not run the remove script"

echo package >"$never_module/.condition_remove_never/never_file"
echo false >"$never_module/.condition"
printf 'touch "%s"\n' "$env_marker" >"$never_module/e.user.sh"
$COVERAGE ./pont.sh -q -r condition_remove_never
sync
[ ! -e "$env_marker" ] ||
	fail "-r ran a script of a module that was never installed"

# Each log line names the module and its condition. Without $COVERAGE: kcov in
# a subshell does not pass the output on.
output=$(./pont.sh -r condition_remove_never 2>&1 >/dev/null)
printf '%s\n' "$output" |
	grep -qF 'Condition on condition_remove_never failed. Skipping. false' ||
	fail "-r did not log the skip: $output"
$COVERAGE ./pont.sh -q condition_remove
echo false >"$module/.condition"
output=$(./pont.sh -r condition_remove 2>&1 >/dev/null)
printf '%s\n' "$output" |
	grep -qF 'Condition on condition_remove failed. No remove scripts. false' ||
	fail "-r did not log the failed condition: $output"
for flag in -x -u; do
	output=$(./pont.sh "$flag" condition_remove 2>&1 >/dev/null)
	printf '%s\n' "$output" |
		grep -qF 'Condition on condition_remove failed. Skipping. false' ||
		fail "$flag did not log the failed condition: $output"
done
