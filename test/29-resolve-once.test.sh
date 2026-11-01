#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Each module and preset resolves once, whatever condition and blanks its
# entries have, and a cycle through conditional entries ends

modules="resolve_once_a resolve_once_b resolve_once_c resolve_once_d"
modules="$modules resolve_once_shared resolve_cycle_a resolve_cycle_b"
modules="$modules resolveXonce resolve.once resolve_tag_user resolve_tagged"
presets="resolve_cycle_p1 resolve_cycle_p2"
cleanup() {
	for module in $modules; do
		rm -rf "${PONT_MODULES_HOME:?}/$module"
	done
	for preset in $presets; do
		rm -f "${PONT_PRESETS_HOME:?}/$preset.preset"
	done
}
trap cleanup EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
for module in $modules; do
	mkdir -p "$PONT_MODULES_HOME/$module"
done
printf '%s\n' 'resolve_once_shared ? [ -n x ]' \
	>"$PONT_MODULES_HOME/resolve_once_a/.dependencies"
printf '%s\n' 'resolve_once_shared ? [ -n "x" ]' \
	>"$PONT_MODULES_HOME/resolve_once_b/.dependencies"
printf '%s\n' 'resolve_once_shared' \
	>"$PONT_MODULES_HOME/resolve_once_c/.dependencies"
printf '%b' 'resolve_once_shared  ? [ -n x ]\n' \
	'resolve_once_shared\t? [ -n x ]\n' \
	>"$PONT_MODULES_HOME/resolve_once_d/.dependencies"
printf '%s\n' 'resolve_cycle_b ? [ -n x ]' \
	>"$PONT_MODULES_HOME/resolve_cycle_a/.dependencies"
printf '%s\n' 'resolve_cycle_a ? [ -n x ]' \
	>"$PONT_MODULES_HOME/resolve_cycle_b/.dependencies"
printf '%s\n' ':resolve_tag ? [ -n x ]' ':resolve_tag ? [ -n "x" ]' \
	>"$PONT_MODULES_HOME/resolve_tag_user/.dependencies"
printf '%s\n' 'resolve_tag' >"$PONT_MODULES_HOME/resolve_tagged/.tags"
printf '%s\n' '+resolve_cycle_p2 ? [ -n x ]' 'resolve_once_a' \
	>"$PONT_PRESETS_HOME/resolve_cycle_p1.preset"
printf '%s\n' '+resolve_cycle_p1 ? [ -n x ]' 'resolve_once_b' \
	>"$PONT_PRESETS_HOME/resolve_cycle_p2.preset"

$COVERAGE ./pont.sh -eL resolve_once_a resolve_once_b resolve_once_c \
	resolve_once_d >/dev/null
result=$(./pont.sh -eL resolve_once_a resolve_once_b resolve_once_c \
	resolve_once_d)
[ "$result" = "resolve_once_shared
resolve_once_a
resolve_once_b
resolve_once_c
resolve_once_d" ] ||
	{ echo "A module resolved more than once: $result"; exit 1; }

result=$(timeout 10 ./pont.sh -eL resolve_cycle_a) ||
	{ echo "The expansion of a dependency cycle did not end"; exit 1; }
[ "$result" = "resolve_cycle_b
resolve_cycle_a" ] ||
	{ echo "A module of a dependency cycle resolved twice: $result"; exit 1; }

result=$(timeout 10 ./pont.sh -nL +resolve_cycle_p1) ||
	{ echo "The expansion of a preset cycle did not end"; exit 1; }
[ "$result" = "resolve_once_b
resolve_once_a" ] ||
	{ echo "A preset of a preset cycle resolved twice: $result"; exit 1; }

# The module list hides a repeated tag, so the trace shows the skipped entry
skipped=$(PONT_LOG_LEVEL=0 ./pont.sh -eL resolve_tag_user 2>&1 >/dev/null |
	grep -c 'already resolved :resolve_tag' || true)
[ "$skipped" = 1 ] ||
	{ echo "A tag resolved more than once: $skipped skipped"; exit 1; }

result=$(./pont.sh -eL resolveXonce resolve.once)
[ "$result" = "resolveXonce
resolve.once" ] ||
	{ echo "A module name matched another as a pattern: $result"; exit 1; }
