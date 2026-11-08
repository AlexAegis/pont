#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

modules="init_result_ok init_result_status init_result_condition"
modules="$modules env_result_status env_result_condition env_result_later"
other_modules="make_result_ok make_result_failed cd_result_failed"
hashes="$PONT_TARGET/init_env_results_hashes"
cleanup() {
	[ ! -d "$PONT_MODULES_HOME/cd_result_failed" ] ||
		chmod 755 "$PONT_MODULES_HOME/cd_result_failed"
	for module in $modules $other_modules; do
		rm -rf "${PONT_MODULES_HOME:?}/$module"
	done
}
trap cleanup EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
cleanup
for module in $modules; do
	mkdir -p "$PONT_MODULES_HOME/$module"
	cat >"$PONT_MODULES_HOME/$module/1.user.sh" <<EOF
#!/bin/sh
: >"\$PONT_TARGET/$module.1.ran"
EOF
	chmod +x "$PONT_MODULES_HOME/$module/1.user.sh"
done
echo true >"$PONT_MODULES_HOME/init_result_ok/i.user.sh"
echo true >"$PONT_MODULES_HOME/init_result_ok/e.user.sh"
echo 'return 3' >"$PONT_MODULES_HOME/init_result_status/i.user.sh"
echo true >"$PONT_MODULES_HOME/init_result_condition/i.user.sh"
echo 'exit 2' >"$PONT_MODULES_HOME/init_result_condition/i.user.sh.condition"
echo 'return 1' >"$PONT_MODULES_HOME/env_result_status/e.user.sh"
echo true >"$PONT_MODULES_HOME/env_result_condition/e.user.sh"
echo 'exit 2' >"$PONT_MODULES_HOME/env_result_condition/e.user.sh.condition"
cat >"$PONT_MODULES_HOME/env_result_later/e.user.sh" <<'EOF'
[ -z "$PONT_TEST_FAILING_ENV" ]
EOF

hashed() {
	[ -e "$PONT_MODULES_HOME/$1/.tarhash" ]
}

# shellcheck disable=SC2086
$COVERAGE ./pont.sh -q -fx $modules || true
for module in $modules; do
	[ -e "$PONT_TARGET/$module.1.ran" ] ||
		fail "Install script of $module did not run"
done
hashed init_result_ok || fail "Module with passing init and env got no hash"
hashed env_result_later || fail "Module with passing env got no hash"
! hashed init_result_status ||
	fail "Module whose sourced init script returned 3 got a hash"
! hashed init_result_condition ||
	fail "Module whose init condition exited 2 got a hash"
! hashed env_result_status ||
	fail "Module whose sourced env script returned 1 got a hash"
! hashed env_result_condition ||
	fail "Module whose env condition exited 2 got a hash"

rm "$PONT_TARGET/env_result_later.1.ran"
PONT_TEST_FAILING_ENV=1 $COVERAGE ./pont.sh -q -x env_result_later || true
[ ! -e "$PONT_TARGET/env_result_later.1.ran" ] ||
	fail "Up to date module was installed again"
hashed env_result_later ||
	fail "Failed env script of an up to date module removed its hash"

if command -v make >/dev/null; then
	mkdir -p "$PONT_MODULES_HOME/make_result_ok" \
		"$PONT_MODULES_HOME/make_result_failed"
	printf 'all:\n\ttrue\n' >"$PONT_MODULES_HOME/make_result_ok/Makefile"
	printf 'all:\n\tfalse\n' >"$PONT_MODULES_HOME/make_result_failed/Makefile"
	$COVERAGE ./pont.sh -q -fx make_result_ok make_result_failed || true
	hashed make_result_ok || fail "Module with passing make got no hash"
	! hashed make_result_failed || fail "Module with failed make got a hash"
	printf 'all:\n\ttouch make-ran\n\tfalse\n' \
		>"$PONT_MODULES_HOME/make_result_failed/Makefile"
	echo old >"$PONT_MODULES_HOME/make_result_failed/.tarhash"
	$COVERAGE ./pont.sh -q -d -fx make_result_failed || true
	[ ! -e "$PONT_MODULES_HOME/make_result_failed/make-ran" ] ||
		fail "Dry run ran make"
	hashed make_result_failed || fail "Dry run removed the hash of a make module"
else
	echo "make not available, make results not checked"
fi

if [ "$(id -u)" != 0 ]; then
	mkdir -p "$PONT_MODULES_HOME/cd_result_failed" "$hashes"
	chmod 644 "$PONT_MODULES_HOME/cd_result_failed"
	PONT_HASH_HOME="$hashes" $COVERAGE ./pont.sh -q -fx cd_result_failed ||
		true
	[ ! -e "$hashes/cd_result_failed.tarhash" ] ||
		fail "Module that pont cannot enter got a hash"
	echo old >"$hashes/cd_result_failed.tarhash"
	PONT_HASH_HOME="$hashes" $COVERAGE ./pont.sh -q -d -fx cd_result_failed ||
		true
	[ -e "$hashes/cd_result_failed.tarhash" ] ||
		fail "Dry run removed the hash of a module that pont cannot enter"
else
	echo "Root enters every folder, cd results not checked"
fi
