#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# A tag selects only the modules that have that exact tag, also when blanks or
# a comment follow it, and characters of a regular expression stay literal.
# A tags file that cannot be read does not hide the others.

modules="exact_tags_0 exact_tags_a exact_tags_b exact_tags_c exact_tags_d"
modules="$modules exact_tags_e exact_tags_f exact_tags_g exact_tags_h"
modules="$modules exact_tags_i exact_tags_j exact_tags_k exact_tags_1"
modules="$modules exact_tags_2"
cleanup() {
	for module in $modules; do
		rm -rf "${PONT_MODULES_HOME:?}/$module"
	done
}
trap cleanup EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
for module in $modules; do
	mkdir -p "$PONT_MODULES_HOME/$module"
done
tags() {
	printf '%b' "$2" >"$PONT_MODULES_HOME/exact_tags_$1/.tags"
}
tags a 'exact_tag\n'
tags b 'exact_tag_longer\n'
tags c 'exact_tag # comment\n'
tags d 'exact.tag\n'
tags e 'exact_tag\t# comment\n'
tags f 'exact_tag#comment\n'
tags g 'exact_tag\r\n'
tags h 'exact|tag\n'
tags i 'exact_tag++\n'
tags j '# exact_tag\n'
tags k 'exact_tag \t\n'
ln -s missing "$PONT_MODULES_HOME/exact_tags_0/.tags"
unreadable="exact_tags_0 exact_tags_2"
mkdir "$PONT_MODULES_HOME/exact_tags_2/.tags"
# root reads a file of mode 000
if [ "$(id -u)" != 0 ]; then
	tags 1 'exact_tag\n'
	chmod 000 "$PONT_MODULES_HOME/exact_tags_1/.tags"
	unreadable="$unreadable exact_tags_1"
fi

$COVERAGE ./pont.sh -nL :exact_tag >/dev/null 2>&1
result=$(./pont.sh -nL :exact_tag 2>/dev/null)
[ "$result" = "exact_tags_a
exact_tags_c
exact_tags_e
exact_tags_f
exact_tags_g
exact_tags_k" ] ||
	{ echo "The tag exact_tag selected: $result"; exit 1; }
errors=$(./pont.sh -nL :exact_tag 2>&1 >/dev/null)
for module in $unreadable; do
	printf '%s\n' "$errors" | grep -qF \
		"Tags file not readable: $PONT_MODULES_HOME/$module/.tags" ||
		{ echo "No warning for the tags file of $module"; exit 1; }
done

for tag in exact.tag 'exact|tag' exact_tag++; do
	result=$(./pont.sh -nL ":$tag" 2>/dev/null | tr '\n' ' ')
	case $tag in
	exact.tag) expected='exact_tags_d ' ;;
	'exact|tag') expected='exact_tags_h ' ;;
	exact_tag++) expected='exact_tags_i ' ;;
	esac
	[ "$result" = "$expected" ] ||
		{ echo "The tag $tag selected: $result"; exit 1; }
done

result=$(./pont.sh -nL : 2>/dev/null)
[ -z "$result" ] || { echo "The empty tag selected: $result"; exit 1; }

# Without a tags file to read, the tag must not read the standard input
mkdir -p "$PONT_TARGET/no_tags/untagged"
result=$(printf 'exact_tag\n' |
	PONT_MODULES_HOME="$PONT_TARGET/no_tags" ./pont.sh -nL :exact_tag)
[ -z "$result" ] ||
	{ echo "Without tags files, the tag selected: $result"; exit 1; }
