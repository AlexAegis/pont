#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# The fallbacks of a group run only when no other script of the group applies.
# Their result is then the result of the group, not the result of the module.

# Modules that this test makes, so that the module list of test 09 stays
# unchanged
blocked="$PONT_MODULES_HOME/fallback_result_blocked"
condition="$PONT_MODULES_HOME/fallback_result_condition"
recovered="$PONT_MODULES_HOME/fallback_result_recovered"
failed="$PONT_MODULES_HOME/fallback_result_failed"
mixed="$PONT_MODULES_HOME/fallback_result_mixed"
earlier="$PONT_MODULES_HOME/fallback_result_earlier"
out="$PONT_TARGET/fallback_result"
remove_modules() {
	rm -rf "$blocked" "$condition" "$recovered" "$failed" "$mixed" "$earlier"
}
trap remove_modules EXIT
trap 'exit 1' HUP INT TERM
remove_modules
mkdir -p "$blocked" "$condition" "$recovered" "$failed" "$mixed" "$earlier" \
	"$out"

make_script() {
	cat >"$1" <<EOF
#!/bin/sh
: >"$out/$2"
exit $3
EOF
	chmod +x "$1"
}

export PONT_PACKAGE_MANAGERS="sh pont_test_missing_manager"
missing=pont_test_missing_manager

make_script "$blocked/0.user.sh.sh" blocked-package 1
make_script "$blocked/0.user.fallback.sh" blocked-fallback 0
make_script "$condition/0.user.sh.sh" condition-package 0
echo 'exit 2' >"$condition/0.user.sh.sh.condition"
make_script "$condition/0.user.fallback.sh" condition-fallback 0
make_script "$recovered/0.user.$missing.sh" recovered-package 0
make_script "$recovered/0.user.fallback.sh" recovered-fallback 0
make_script "$failed/0.user.$missing.sh" failed-package 0
make_script "$failed/0.user.fallback.sh" failed-fallback 1
make_script "$mixed/0.user.$missing.sh" mixed-package 0
make_script "$mixed/0.user.fallback.sh" mixed-fallback 0
make_script "$mixed/0.user-second.fallback.sh" mixed-fallback-second 1
make_script "$earlier/0.user.sh" earlier-plain 1
make_script "$earlier/1.user.$missing.sh" earlier-package 0
make_script "$earlier/1.user.fallback.sh" earlier-fallback 0

$COVERAGE ./pont.sh -q fallback_result_blocked fallback_result_condition \
	fallback_result_recovered fallback_result_failed fallback_result_mixed \
	fallback_result_earlier
sync
for name in blocked-package recovered-fallback failed-fallback \
	mixed-fallback mixed-fallback-second earlier-plain earlier-fallback; do
	[ -e "$out/$name" ] || fail "Script $name did not run"
done
for name in blocked-fallback condition-package condition-fallback \
	recovered-package failed-package mixed-package earlier-package; do
	[ ! -e "$out/$name" ] || fail "Script $name ran"
done
[ ! -e "$blocked/.tarhash" ] ||
	fail "A module whose package manager script failed got a hash"
[ ! -e "$condition/.tarhash" ] ||
	fail "A module whose condition file failed got a hash"
[ -e "$recovered/.tarhash" ] ||
	fail "A module whose fallback succeeded got no hash"
[ ! -e "$failed/.tarhash" ] ||
	fail "A module whose fallback failed got a hash"
[ ! -e "$mixed/.tarhash" ] ||
	fail "A module with one failed fallback of two got a hash"
[ ! -e "$earlier/.tarhash" ] ||
	fail "A fallback hid the failure of an earlier group"
