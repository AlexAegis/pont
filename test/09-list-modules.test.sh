#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all presets
result=$($COVERAGE ./dot.sh -A)
echo "$result"
# Assertions
sync
[ "$result" = "base
conditional_symlinks
permissions
symlinks
systemd" ] ||
 	{ echo "Not all presets have been listed!"; exit 1; }
