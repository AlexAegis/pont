#!/bin/sh
# shellcheck disable=SC1091
. ./test/.env
# This test tries to install the "symlinks" module which have multiple
# linkable packages inside, two of which use relative paths and will be linked
# to DOT_TARGET without mentioning it. One that's an absolute path, and one
# that has no variable target, and will default to DOT_TARGET.
"$COVERAGE" "$COVERAGE_TARGET" ./dot.sh -q symlinks

# Assertions
sync
echo "$DOT_TARGET/base"
[ -e "$DOT_TARGET/symlinksfile" ] ||
	{ echo "Base not linked"; exit 1; }
[ -e "$DOT_TARGET/symlinks/target_relative/relative" ] ||
	{ echo "Relative not linked"; exit 1; }
[ -e "$DOT_TARGET/symlinks/target_absolute/absolute" ] ||
	{ echo "Absolute not linked"; exit 1; }
