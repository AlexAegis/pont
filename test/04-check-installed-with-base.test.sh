#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/.env
# This test tries to install the "symlinks" module while having the
# DOT_BASE_MODULES set to "base" which should make that module install too.
export DOT_BASE_MODULES="base"
$COVERAGE ./dot.sh -q symlinks
expected_installed="base
symlinks"
installed=$($COVERAGE ./dot.sh -I)
# Assertions
sync
[ "$installed" =  "$expected_installed" ] ||
 	{ echo "Installed list not correct"; exit 1; }
