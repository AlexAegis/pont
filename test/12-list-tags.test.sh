#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all deprecated modules
$COVERAGE ./pont.sh -T
result=$(./pont.sh -T)
# Assertions
sync
[ "$result" = "basetag" ] ||
 	{ echo "Not all deprecated modules have been listed!"; exit 1; }
