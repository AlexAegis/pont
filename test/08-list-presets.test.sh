#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all presets, and that it lists each
# preset by its file name without the extension
preset="$PONT_PRESETS_HOME/more/list_presets_preset.preset"
trap 'rm -f "$preset"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
: >"$preset"
$COVERAGE ./pont.sh -P
result=$(./pont.sh -P)
# Assertions
sync
[ "$result" = "a
b
list_presets_preset" ] ||
 	{ echo "Not all presets have been listed!"; exit 1; }
