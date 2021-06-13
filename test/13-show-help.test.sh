#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if that both the help and version functions work
# And that their first lines are the same
$COVERAGE ./pont.sh -h > /dev/null
$COVERAGE ./pont.sh -V > /dev/null
help_result=$(./pont.sh -h | sed 1q)
version_result=$(./pont.sh -V)
# Assertions
sync
[ "$help_result" = "$version_result" ] ||
 	{ echo "Help and version mismatch!"; exit 1; }
