#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if that both the help and version functions work
# And that their first lines are the same
help_result=$($COVERAGE ./dot.sh -h | sed 1q)
version_result=$($COVERAGE ./dot.sh -V)
# Assertions
sync
[ "$help_result" = "$version_result" ] ||
 	{ echo "Help and version mismatch!"; exit 1; }
