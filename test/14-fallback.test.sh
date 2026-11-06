#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

$COVERAGE ./pont.sh -q fallback

# Assertions
sync
[ -e "$PONT_TARGET/fallback/output" ] ||
	fail "Fallback script did not run"
[ ! -e "$PONT_TARGET/fallback/unavailable" ] ||
	fail "Unavailable script ran"
