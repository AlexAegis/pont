#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

$COVERAGE ./pont.sh -q lone_fallback

# Assertions
sync
[ -e "$PONT_TARGET/lone_fallback/output" ] ||
	{ echo "Fallback script did not run"; exit 1; }
