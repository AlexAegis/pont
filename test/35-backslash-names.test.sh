#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Names of modules, presets and tags keep their backslashes in every shell: in
# the selection, in each listing, in the copies of -y and in the log lines

name='backslash_names\tname'
module="$PONT_MODULES_HOME/$name"
preset="$PONT_PRESETS_HOME/backslash_names\\bpreset.preset"
trap 'rm -rf "$module" "$preset"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module"
printf '%s\n' 'backslash_names\btag' >"$module/.tags"
printf '%s\n' "$name" >"$preset"
printf '%s\n' stale >"$module/.tarhash"
: >"$module/.deprecated"
hash_home="$PONT_TARGET/backslash_names_hashes"
mkdir -p "$hash_home"
printf '%s\n' stale >"$hash_home/$name.tarhash"

$COVERAGE ./pont.sh -nL ':backslash_names\btag' >/dev/null 2>&1
pont="$(pwd)/pont.sh"
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	for entry in ':backslash_names\btag' '+backslash_names\bpreset'; do
		result=$("$shell" "$pont" -nL "$entry" 2>/dev/null)
		[ "$result" = "$name" ] ||
			{ printf '%s\n' "$shell selected for $entry: $result"; exit 1; }
	done
	for list in '-T backslash_names\btag' '-P backslash_names\bpreset' \
		"-A $name" "-D $name" "-I $name" "-O $name"; do
		"$shell" "$pont" "${list%% *}" | grep -qxF -- "${list#* }" ||
			{ printf '%s\n' "$shell $list: not listed"; exit 1; }
	done
	for flag in -I -O; do
		PONT_HASH_HOME=$hash_home "$shell" "$pont" "$flag" |
			grep -qxF -- "$name" || {
			printf '%s\n' "$shell $flag with PONT_HASH_HOME: $name not listed"
			exit 1
		}
	done
	yank="$PONT_TARGET/backslash_names_yank_$shell"
	mkdir -p "$yank"
	"$shell" "$pont" -y "$yank" '+backslash_names\bpreset' >/dev/null 2>&1
	[ -e "$yank/backslash_names\\bpreset.preset" ] ||
		{ echo "$shell did not copy the preset"; exit 1; }
	logs=$("$shell" "$pont" -v -nL ':backslash_names\btag' 2>&1 >/dev/null)
	logs="$logs
$("$shell" "$pont" -fx "$name" 2>&1 >/dev/null || true)
$("$shell" "$pont" -y "$yank" '+backslash_names\bmissing' 2>&1 >/dev/null)"
	printf '%s\n' "$logs" | grep -qxF -- "$name$(printf '\033[0m')" ||
		{ printf '%s\n' "$shell did not log the module list: $logs"; exit 1; }
	for text in 'Trying to expand :backslash_names\btag...' \
		"Module $name not found. Skipping" \
		'Preset backslash_names\bmissing.preset not found, not yanked'; do
		printf '%s\n' "$logs" | grep -qF -- "$text" ||
			{ printf '%s\n' "$shell did not log: $text"; exit 1; }
	done
done
