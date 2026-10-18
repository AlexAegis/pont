#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# The packages module has a group whose script has the condition sh, a
# command that exists, and a group whose condition nonexistent is not
# installed. With both listed as package managers, a skip of package scripts
# skips them and counts them as done, so the fallbacks of both groups stay off.

export PONT_PACKAGE_MANAGERS="nonexistent sh"

$COVERAGE ./pont.sh -q --skip-packages packages
sync
[ -e "$PONT_TARGET/packages/plain" ] ||
	{ echo "Script without a condition did not run"; exit 1; }
[ ! -e "$PONT_TARGET/packages/package" ] ||
	{ echo "Package script ran with --skip-packages"; exit 1; }
[ ! -e "$PONT_TARGET/packages/fallback" ] ||
	{ echo "Fallback ran after a skipped package script"; exit 1; }
[ ! -e "$PONT_TARGET/packages/absent-fallback" ] ||
	{ echo "Fallback ran after a skipped script of a missing manager"; exit 1; }

rm -r "${PONT_TARGET:?}/packages"
$COVERAGE ./pont.sh -q -fx packages
sync
[ -e "$PONT_TARGET/packages/package" ] ||
	{ echo "Package script did not run by default"; exit 1; }
[ ! -e "$PONT_TARGET/packages/fallback" ] ||
	{ echo "Fallback ran after a successful package script"; exit 1; }
[ -e "$PONT_TARGET/packages/absent-fallback" ] ||
	{ echo "Fallback of a missing manager did not run by default"; exit 1; }

rm -r "${PONT_TARGET:?}/packages"
$COVERAGE ./pont.sh -q -fxR packages
sync
[ ! -e "$PONT_TARGET/packages/package" ] ||
	{ echo "Package script ran with --skip-root"; exit 1; }
[ ! -e "$PONT_TARGET/packages/fallback" ] ||
	{ echo "Fallback ran after --skip-root"; exit 1; }
[ ! -e "$PONT_TARGET/packages/absent-fallback" ] ||
	{ echo "Fallback of a missing manager ran after --skip-root"; exit 1; }

rm -r "${PONT_TARGET:?}/packages"
$COVERAGE ./pont.sh -q -fxR --packages packages
sync
[ -e "$PONT_TARGET/packages/package" ] ||
	{ echo "Package script did not run with --packages"; exit 1; }
