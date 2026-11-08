#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

module="$PONT_MODULES_HOME/dry_run"
target="$PONT_TARGET/dry_run_target"
trap 'rm -rf "$module"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
rm -rf "$module" "$target"
mkdir -p "$module/DRY_RUN_TARGET.dry_run"
echo package >"$module/DRY_RUN_TARGET.dry_run/dry_run_file"
DRY_RUN_TARGET="$target"
export DRY_RUN_TARGET

$COVERAGE ./pont.sh -q -d -fx dry_run
[ ! -e "$target" ] || fail "Dry run made the target folder of a package"
[ ! -e "$module/.tarhash" ] || fail "Dry run made a hash"

$COVERAGE ./pont.sh -q -fx dry_run
[ -L "$target/dry_run_file" ] || fail "Install did not link the package"
[ -e "$module/.tarhash" ] || fail "Install made no hash"

$COVERAGE ./pont.sh -q -d -r dry_run
[ -e "$module/.tarhash" ] || fail "Dry run of a removal removed the hash"
[ -L "$target/dry_run_file" ] ||
	fail "Dry run of a removal removed the link of the package"
