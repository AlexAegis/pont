#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all presets
$COVERAGE ./pont.sh -P
result=$(./pont.sh -P)
# Assertions
sync
[ "$result" = "a
b" ] ||
 	{ echo "Not all presets have been listed!"; exit 1; }
