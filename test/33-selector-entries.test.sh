#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# The selector lists presets with +, tags with : and modules without a prefix,
# each name as one literal entry, and selects the entries that whiptail returns

module_name='selector_entries[1]'
module="$PONT_MODULES_HOME/$module_name"
preset="$PONT_PRESETS_HOME/selector_entries[1].preset"
cwd="$PONT_TARGET/selector_entries"
bin="$PONT_TARGET/selector_entries_bin"
export SELECTOR_ENTRIES_ARGUMENTS="$PONT_TARGET/selector_entries_arguments"
export SELECTOR_ENTRIES_CHOICE='+selector_entries[1]'
trap 'rm -rf "$module" "$preset"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module" "$cwd" "$bin"
printf '%s\n' 'selector_entries_tag[1]' >"$module/.tags"
printf '%s\n' "$module_name" >"$preset"
: >"$cwd/selector_entries1"
: >"$cwd/:selector_entries_tag1"
: >"$cwd/+selector_entries1"
cat >"$bin/whiptail" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$SELECTOR_ENTRIES_ARGUMENTS"
printf '%s\n' "$SELECTOR_ENTRIES_CHOICE" >&2
EOF
chmod +x "$bin/whiptail"
pont="$(pwd)/pont.sh"

has_checklist_item() {
	_entry=$1 awk '
		$0 == "OFF" && item == ENVIRON["_entry"] && tag == item { found = 1 }
		{ tag = item; item = $0 }
		END { exit !found }
	' "$SELECTOR_ENTRIES_ARGUMENTS"
}

PATH="$bin:$PATH" $COVERAGE ./pont.sh -c -eL >/dev/null
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	rm -f "$SELECTOR_ENTRIES_ARGUMENTS"
	result=$(cd "$cwd" && PATH="$bin:$PATH" "$shell" "$pont" -c -eL)
	awk '
		$0 == "--separate-output" && !list { separate = 1 }
		$0 == "--checklist" { list = 1 }
		END { exit !separate }
	' "$SELECTOR_ENTRIES_ARGUMENTS" ||
		{ echo "$shell asked for the selection on one line"; exit 1; }
	for entry in '+selector_entries[1]' ':selector_entries_tag[1]' \
		"$module_name"; do
		has_checklist_item "$entry" ||
			{ echo "$shell did not list $entry as an item"; exit 1; }
	done
	[ "$result" = "$module_name" ] ||
		{ echo "$shell selected other modules: $result"; exit 1; }
done
