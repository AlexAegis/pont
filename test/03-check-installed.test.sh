#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test tries to install the "symlinks" module which have multiple
# linkable packages inside, two of which use relative paths and will be linked
# to PONT_TARGET without mentioning it. One that's an absolute path, and one
# that has no variable target, and will default to PONT_TARGET.

$COVERAGE ./pont.sh -q symlinks conditional_symlinks
expected_installed="conditional_symlinks
symlinks"
installed=$($COVERAGE ./pont.sh -I)
echo "installed $installed"
# Assertions
sync
[ "$installed" =  "$expected_installed" ] ||
 	{ echo "Installed list not correct"; exit 1; }
