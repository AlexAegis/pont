#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all deprecated modules
$COVERAGE ./pont.sh -D
result=$(./pont.sh -D)
# Assertions
sync
[ "$result" = "deprecated" ] ||
 	{ echo "Not all deprecated modules have been listed!"; exit 1; }
