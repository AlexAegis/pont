#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# sh exists and nonexistent does not. Both count as package managers.
# Skipped scripts count as done, so neither group runs its fallback.

export PONT_PACKAGE_MANAGERS="nonexistent sh"
out="$PONT_TARGET/package_manager_scripts"

$COVERAGE ./pont.sh -q --skip-package-manager-scripts package_manager_scripts
sync
[ -e "$out/plain" ] ||
	{ echo "Script without a condition did not run"; exit 1; }
[ ! -e "$out/package" ] ||
	{ echo "Package manager script ran when skipped"; exit 1; }
[ ! -e "$out/fallback" ] ||
	{ echo "Fallback ran after a skipped package manager script"; exit 1; }
[ ! -e "$out/absent-fallback" ] ||
	{ echo "Fallback ran after a skipped script of a missing manager"; exit 1; }

rm -r "${out:?}"
$COVERAGE ./pont.sh -q -fx package_manager_scripts
sync
[ -e "$out/package" ] ||
	{ echo "Package manager script did not run by default"; exit 1; }
[ ! -e "$out/fallback" ] ||
	{ echo "Fallback ran after a successful package manager script"; exit 1; }
[ -e "$out/absent-fallback" ] ||
	{ echo "Fallback of a missing manager did not run by default"; exit 1; }

rm -r "${out:?}"
$COVERAGE ./pont.sh -q -fxR package_manager_scripts
sync
[ ! -e "$out/package" ] ||
	{ echo "Package manager script ran with --skip-root"; exit 1; }
[ ! -e "$out/fallback" ] ||
	{ echo "Fallback ran after --skip-root"; exit 1; }
[ ! -e "$out/absent-fallback" ] ||
	{ echo "Fallback of a missing manager ran after --skip-root"; exit 1; }

rm -r "${out:?}"
$COVERAGE ./pont.sh -q -fxR --package-manager-scripts package_manager_scripts
sync
[ -e "$out/package" ] ||
	{ echo "Package manager script did not run when enabled"; exit 1; }
