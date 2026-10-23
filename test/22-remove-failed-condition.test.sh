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
	{ echo "The module did not install"; exit 1; }

echo false >"$module/.condition"
./pont.sh -O | grep -qx condition_remove ||
	{ echo "-O does not list the module before -r"; exit 1; }
$COVERAGE ./pont.sh -q -rr condition_remove
sync
[ ! -L "$link" ] || { echo "-r kept the links of the module"; exit 1; }
[ ! -e "$hash" ] || { echo "-r kept the hash of the module"; exit 1; }
[ ! -e "$marker" ] || {
	echo "-rr ran a remove script of a module whose condition failed"
	exit 1
}

# With its condition, -rr runs the remove scripts
rm "$module/.condition"
$COVERAGE ./pont.sh -q condition_remove
$COVERAGE ./pont.sh -q -rr condition_remove
sync
[ -e "$marker" ] || { echo "-rr did not run the remove script"; exit 1; }

echo package >"$never_module/.condition_remove_never/never_file"
echo false >"$never_module/.condition"
printf 'touch "%s"\n' "$env_marker" >"$never_module/e.user.sh"
$COVERAGE ./pont.sh -q -r condition_remove_never
sync
[ ! -e "$env_marker" ] ||
	{ echo "-r ran a script of a module that was never installed"; exit 1; }

# Each log line names the module and its condition. Without $COVERAGE: kcov in
# a subshell does not pass the output on.
output=$(./pont.sh -r condition_remove_never 2>&1 >/dev/null)
printf '%s\n' "$output" |
	grep -qF 'Condition on condition_remove_never failed. Skipping. false' ||
	{ echo "-r did not log the skip: $output"; exit 1; }
$COVERAGE ./pont.sh -q condition_remove
echo false >"$module/.condition"
output=$(./pont.sh -r condition_remove 2>&1 >/dev/null)
printf '%s\n' "$output" |
	grep -qF 'Condition on condition_remove failed. No remove scripts. false' ||
	{ echo "-r did not log the failed condition: $output"; exit 1; }
for flag in -x -u; do
	output=$(./pont.sh "$flag" condition_remove 2>&1 >/dev/null)
	printf '%s\n' "$output" |
		grep -qF 'Condition on condition_remove failed. Skipping. false' ||
		{ echo "$flag did not log the failed condition: $output"; exit 1; }
done
