#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test tries to install the "symlinks" module which have multiple
# linkable packages inside, two of which use relative paths and will be linked
# to PONT_TARGET without mentioning it. One that's an absolute path, and one
# that has no variable target, and will default to PONT_TARGET.
$COVERAGE ./pont.sh -q symlinks

# Assertions
sync
echo "$PONT_TARGET/base"
[ -e "$PONT_TARGET/symlinksfile" ] ||
	{ echo "Base not linked"; exit 1; }
[ -e "$PONT_TARGET/symlinks/target_relative/relative" ] ||
	{ echo "Relative not linked"; exit 1; }
[ -e "$PONT_TARGET/symlinks/target_absolute/absolute" ] ||
	{ echo "Absolute not linked"; exit 1; }
