#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
module="$PONT_MODULES_HOME/script_failure"
env_module="$PONT_MODULES_HOME/script_failure_env"
broken="$PONT_MODULES_HOME/script_failure_condition"
deprecated="$PONT_MODULES_HOME/script_failure_deprecated"
trap 'rm -rf "$module" "$env_module" "$broken" "$deprecated"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module" "$env_module" "$broken" "$deprecated"
mkdir -p "$module" "$env_module" "$broken" "$deprecated"
printf '#!/bin/sh\nexit 4\n' >"$module/u.user.sh"
printf '#!/bin/sh\nexit 3\n' >"$module/r.user.sh"
chmod +x "$module/u.user.sh" "$module/r.user.sh"

failed_modules=1 $COVERAGE ./pont.sh -q script_failure ||
	fail "pont exited with non-zero after an install without a failure"
$COVERAGE ./pont.sh -q -u script_failure 2>/dev/null &&
	fail "pont exited with 0 after a failed update script"
$COVERAGE ./pont.sh -q -rr script_failure 2>/dev/null &&
	fail "pont exited with 0 after a failed remove script"

# shellcheck disable=SC2016
echo '[ -z "$SCRIPT_FAILURE_ENV" ]' >"$env_module/e.user.sh"
$COVERAGE ./pont.sh -q script_failure_env
SCRIPT_FAILURE_ENV=1 $COVERAGE ./pont.sh -q script_failure_env 2>/dev/null &&
	fail "pont exited with 0 after a failed env script of an installed module"
SCRIPT_FAILURE_ENV=1 $COVERAGE ./pont.sh -q -u script_failure_env 2>/dev/null &&
	fail "pont exited with 0 after a failed env script at -u"
SCRIPT_FAILURE_ENV=1 $COVERAGE ./pont.sh -q -r script_failure_env 2>/dev/null &&
	fail "pont exited with 0 after a failed env script at -r"

printf '%s\n' 'if true' >"$broken/.condition"
$COVERAGE ./pont.sh -q script_failure_condition 2>/dev/null &&
	fail "pont exited with 0 after a syntax error in a condition"

: >"$deprecated/.deprecated"
echo true >"$deprecated/e.user.sh"
$COVERAGE ./pont.sh -q script_failure_deprecated ||
	fail "pont exited with non-zero for a deprecated module without a failure"
echo false >"$deprecated/e.user.sh"
$COVERAGE ./pont.sh -q script_failure_deprecated 2>/dev/null &&
	fail "pont exited with 0 after a failed env script of a deprecated module"
exit 0
