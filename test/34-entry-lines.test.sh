#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Every reader of entry, tag and condition lines ignores a comment, blanks at
# either end of a line and a CR before the newline. A .tags file without a
# final newline keeps its last tag.

modules="entry_lines_root entry_lines_crlf entry_lines_member"
modules="$modules entry_lines_tagged entry_lines_one entry_lines_two"
modules="$modules entry_lines_condition"
preset="$PONT_PRESETS_HOME/entry_lines_preset.preset"
cleanup() {
	for module in $modules; do
		rm -rf "${PONT_MODULES_HOME:?}/$module"
	done
	rm -f "$preset"
}
trap cleanup EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
for module in $modules; do
	mkdir -p "$PONT_MODULES_HOME/$module"
done
lines() {
	printf '%b' "$2" >"$PONT_MODULES_HOME/$1"
}
lines entry_lines_root/.dependencies '\tentry_lines_crlf ? true\r\n'\
'  +entry_lines_preset\r\n \t# comment\r\n :entry_lines_tag # comment\r\n'
printf '%b' '  entry_lines_member \r\n\t \r\n' >"$preset"
lines entry_lines_tagged/.tags ' entry_lines_tag\r\n'
lines entry_lines_one/.tags 'entry_lines_one'
lines entry_lines_two/.tags 'entry_lines_two\r\n\tentry_lines_one\t\n'
lines entry_lines_condition/.condition ' true\r\n'
cat >"$PONT_MODULES_HOME/entry_lines_condition/1.user.sh" <<'EOF'
#!/bin/sh
: >"$PONT_TARGET/entry_lines_condition.ran"
EOF
chmod +x "$PONT_MODULES_HOME/entry_lines_condition/1.user.sh"

$COVERAGE ./pont.sh -eL entry_lines_root >/dev/null 2>&1
result=$(./pont.sh -eL entry_lines_root 2>/dev/null)
[ "$result" = "entry_lines_crlf
entry_lines_member
entry_lines_tagged
entry_lines_root" ] ||
	{ echo "The dependencies of entry_lines_root are: $result"; exit 1; }

result=$(./pont.sh -nL 'entry_lines_crlf # why? false' 2>/dev/null)
[ "$result" = entry_lines_crlf ] ||
	{ echo "A ? in a comment made a condition: $result"; exit 1; }
result=$(./pont.sh -nL '  +entry_lines_preset' 2>/dev/null)
[ "$result" = entry_lines_member ] ||
	{ echo "The preset with leading blanks selected: $result"; exit 1; }

$COVERAGE ./pont.sh -T >/dev/null
tags=$(./pont.sh -T)
for tag in entry_lines_one entry_lines_two entry_lines_tag; do
	count=$(printf '%s\n' "$tags" | grep -cxF -- "$tag" || true)
	[ "$count" = 1 ] ||
		{ echo "-T listed $tag $count times: $tags"; exit 1; }
done
result=$(./pont.sh -nL :entry_lines_one 2>/dev/null | tr '\n' ' ')
[ "$result" = 'entry_lines_one entry_lines_two ' ] ||
	{ echo "The tag entry_lines_one selected: $result"; exit 1; }

$COVERAGE ./pont.sh -fx entry_lines_condition >/dev/null 2>&1
[ -e "$PONT_TARGET/entry_lines_condition.ran" ] ||
	{ echo "The condition with a CR failed"; exit 1; }
