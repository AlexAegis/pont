#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# When no script of a group succeeds, the result of its fallbacks replaces the
# result of the group, not the result of the module.

# Modules that this test makes, so that the module list of test 09 stays
# unchanged
recovered="$PONT_MODULES_HOME/fallback_result_recovered"
failed="$PONT_MODULES_HOME/fallback_result_failed"
mixed="$PONT_MODULES_HOME/fallback_result_mixed"
earlier="$PONT_MODULES_HOME/fallback_result_earlier"
out="$PONT_TARGET/fallback_result"
trap 'rm -rf "$recovered" "$failed" "$mixed" "$earlier"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$recovered" "$failed" "$mixed" "$earlier"
mkdir -p "$recovered" "$failed" "$mixed" "$earlier" "$out"

make_script() {
	cat >"$1" <<EOF
#!/bin/sh
: >"$out/$2"
exit $3
EOF
	chmod +x "$1"
}

export PONT_PACKAGE_MANAGERS=sh

make_script "$recovered/0.user.sh.sh" recovered-package 1
make_script "$recovered/0.user.fallback.sh" recovered-fallback 0
make_script "$failed/0.user.sh.sh" failed-package 1
make_script "$failed/0.user.fallback.sh" failed-fallback 1
make_script "$mixed/0.user.sh.sh" mixed-package 1
make_script "$mixed/0.user.fallback.sh" mixed-fallback 0
make_script "$mixed/0.user-second.fallback.sh" mixed-fallback-second 1
make_script "$earlier/0.user.sh" earlier-plain 1
make_script "$earlier/1.user.sh.sh" earlier-package 1
make_script "$earlier/1.user.fallback.sh" earlier-fallback 0

$COVERAGE ./pont.sh -q fallback_result_recovered fallback_result_failed \
	fallback_result_mixed fallback_result_earlier
sync
for name in recovered-package recovered-fallback failed-package \
	failed-fallback mixed-package mixed-fallback mixed-fallback-second \
	earlier-plain earlier-package earlier-fallback; do
	[ -e "$out/$name" ] || fail "Script $name did not run"
done
[ -e "$recovered/.tarhash" ] ||
	fail "A module whose fallback succeeded got no hash"
[ ! -e "$failed/.tarhash" ] ||
	fail "A module whose fallback failed got a hash"
[ ! -e "$mixed/.tarhash" ] ||
	fail "A module with one failed fallback of two got a hash"
[ ! -e "$earlier/.tarhash" ] ||
	fail "A fallback hid the failure of an earlier group"
