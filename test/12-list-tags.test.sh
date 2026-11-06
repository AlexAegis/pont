#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all tags
$COVERAGE ./pont.sh -T
result=$(./pont.sh -T)
# Assertions
sync
[ "$result" = "basetag" ] ||
 	fail "Not all tags have been listed!"
