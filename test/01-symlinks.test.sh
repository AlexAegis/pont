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
	fail "Base not linked"
[ -e "$PONT_TARGET/symlinks/target_relative/relative" ] ||
	fail "Relative not linked"
[ -e "$PONT_TARGET/symlinks/target_absolute/absolute" ] ||
	fail "Absolute not linked"

# A & in PONT_TARGET stays in the path of a relative target
amp_target="$PONT_TARGET/a&b"
PONT_TARGET="$amp_target" $COVERAGE ./pont.sh -q -fx symlinks
sync
[ -e "$amp_target/symlinks/target_relative/relative" ] ||
	fail "Relative not linked under a target with a &"
