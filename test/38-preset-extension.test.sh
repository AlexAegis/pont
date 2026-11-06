#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# -P, the expansion and -y use $PONT_PRESET_EXTENSION for the preset files and
# read it as text, not as a pattern

extension='.s[e]t*'
export PONT_PRESET_EXTENSION="$extension"
module="$PONT_MODULES_HOME/preset_extension"
outer="$PONT_PRESETS_HOME/ext_outer$extension"
inner="$PONT_PRESETS_HOME/more/ext_inner$extension"
decoy="$PONT_PRESETS_HOME/ext_decoy.set"
target="$PONT_TARGET/preset_extension"
trap 'rm -rf "$module" "$outer" "$inner" "$decoy"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module"
printf '%s\n' '+ext_inner' >"$outer"
printf '%s\n' 'preset_extension' >"$inner"
: >"$decoy"

$COVERAGE ./pont.sh -P
result=$(./pont.sh -P)
[ "$result" = "ext_inner
ext_outer" ] ||
	fail "-P listed other presets: $result"

result=$(./pont.sh -nL +ext_outer)
[ "$result" = preset_extension ] ||
	fail "+ext_outer expanded to: $result"

mkdir -p "$target"
errors=$(./pont.sh -y "$target" +ext_outer 2>&1 >/dev/null)
case $errors in
*'not found'*) fail "-y missed a preset: $errors" ;;
esac
for copy in preset_extension/ "ext_outer$extension" "ext_inner$extension"; do
	[ -e "$target/$copy" ] || fail "-y did not copy $copy"
done
[ ! -e "$target/ext_decoy.set" ] ||
	fail "-y copied a file that only matches the extension as a pattern"
