#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

$COVERAGE ./pont.sh -q fallback

# Assertions
sync
[ -e "$PONT_TARGET/fallback/output" ] ||
	{ echo "Fallback script did not run"; exit 1; }
[ ! -e "$PONT_TARGET/fallback/unavailable" ] ||
	{ echo "Unavailable script ran"; exit 1; }
