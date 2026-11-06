#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# An invalid value stops pont with an error before the next option runs

errors="$PONT_TARGET/errors"
expect_refused() {
	expected=$1
	shift
	$COVERAGE ./pont.sh "$@" -A >/dev/null 2>&1 || true
	status=0
	listed=$(./pont.sh "$@" -A 2>"$errors") || status=$?
	[ "$status" = 1 ] || fail "pont $* -A exited with status $status"
	[ -z "$listed" ] || fail "pont $* -A listed: $listed"
	grep -qF "$expected" "$errors" ||
		fail "pont $* -A logged: $(cat "$errors")"
}

missing="$PONT_TARGET/missing"
for option in -t --target -y --yank -Y --yank-expanded; do
	expect_refused "Invalid target: $missing" "$option" "$missing"
done
for option in -l --log --log-level; do
	expect_refused "Invalid loglevel: bogus" "$option" bogus
done
