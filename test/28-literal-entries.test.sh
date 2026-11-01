#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Entries of presets, .tags and .dependencies files stay literal: a file whose
# name matches an entry as a glob does not replace the entry

module="$PONT_MODULES_HOME/literal_entries"
dependency="$PONT_MODULES_HOME/literal_entries_dependency"
tagged="$PONT_MODULES_HOME/literal_entries_tagged[1]"
preset="$PONT_PRESETS_HOME/literal_entries.preset"
cwd="$PONT_TARGET/literal_entries"
trap 'rm -rf "$module" "$dependency" "$tagged" "$preset"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module" "$dependency" "$tagged" "$cwd"
# In a glob, [ -n x ] and [ -z x ] are bracket expressions whose ranges, from
# space to n and from space to z, include the letter a
printf '%s\n' 'literal_entries ? [ -n x ]' >"$preset"
printf '%s\n' 'literal_entries_dependency ? [ -n x ]' \
	'literal_entries_skipped ? [ -z x ]' >"$module/.dependencies"
printf '%s\n' 'literal_entries_tag' >"$tagged/.tags"
: >"$cwd/literal_entries x a"
: >"$cwd/literal_entries_dependency x a"
: >"$cwd/literal_entries_skipped x a"
: >"$cwd/literal_entries_tagged1"

$COVERAGE ./pont.sh -eL +literal_entries :literal_entries_tag >/dev/null
pont="$(pwd)/pont.sh"
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	result=$(cd "$cwd" &&
		"$shell" "$pont" -eL +literal_entries :literal_entries_tag)
	[ "$result" = "literal_entries_dependency
literal_entries
literal_entries_tagged[1]" ] ||
		{ echo "$shell expanded an entry as a glob: $result"; exit 1; }
done
