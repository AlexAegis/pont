#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test tries to install the "symlinks" module while having the
# PONT_BASE_MODULES set to "base" which should make that module install too.
export PONT_BASE_MODULES="base"
$COVERAGE ./pont.sh -q symlinks
expected_installed="base
symlinks"
installed=$($COVERAGE ./pont.sh -I)
# Assertions
sync
[ "$installed" =  "$expected_installed" ] ||
 	{ echo "Installed list not correct"; exit 1; }
