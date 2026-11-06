#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# -y and -Y copy the presets that the expansion reads, nested ones included

module="$PONT_MODULES_HOME/yank_presets"
outer="$PONT_PRESETS_HOME/yank_outer.preset"
inner="$PONT_PRESETS_HOME/more/yank_inner.preset"
skipped="$PONT_PRESETS_HOME/yank_skipped.preset"
target="$PONT_TARGET/yank"
trap 'rm -rf "$module" "$outer" "$inner" "$skipped"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module"
printf '%s\n' '+yank_inner ? true # nested' '+yank_skipped ? false' >"$outer"
printf '%s\n' 'yank_presets' >"$inner"
printf '%s\n' 'yank_presets' >"$skipped"

for flag in -y -Y; do
	rm -rf "$target"
	mkdir -p "$target"
	$COVERAGE ./pont.sh "$flag" "$target" +yank_outer >/dev/null
	for copy in yank_presets/ yank_outer.preset yank_inner.preset; do
		[ -e "$target/$copy" ] ||
			fail "$flag did not copy $copy"
	done
	cmp -s "$inner" "$target/yank_inner.preset" ||
		fail "$flag copied another yank_inner.preset"
	[ ! -e "$target/yank_skipped.preset" ] ||
		fail "$flag copied a preset whose condition failed"
done

for flag in -nL -eL; do
	result=$(./pont.sh "$flag" +yank_outer)
	[ "$result" = yank_presets ] ||
		fail "$flag listed presets as modules: $result"
done

errors=$(./pont.sh -y "$target" +yank_missing 2>&1 >/dev/null)
case $errors in
*'yank_missing.preset not found'*) ;;
*) fail "-y named no missing preset: $errors" ;;
esac
case $errors in
*cp:*) fail "-y ran cp for a missing preset: $errors" ;;
esac
