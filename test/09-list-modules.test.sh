#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all presets
$COVERAGE ./pont.sh -A > /dev/null
result=$(./pont.sh -A)
# Assertions
sync
[ "$result" = "base
conditional_symlinks
deprecated
fallback
lone_fallback
permissions
symlinks
systemd" ] ||
 	{ echo "Not all presets have been listed!"; exit 1; }
