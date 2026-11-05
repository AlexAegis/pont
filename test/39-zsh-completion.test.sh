#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# The zsh completion lists the modules, presets and tags that pont lists, also
# when only a pontrc names their folders, from the first completion of a shell

command -v zsh >/dev/null || { echo "zsh is not installed"; exit 1; }
harness="$PWD/test/complete.zsh"
bin="$PONT_TARGET/bin"
mkdir -p "$bin"
ln -s "$PWD/pont.sh" "$bin/pont"
PATH="$bin:$PATH"
export PATH

list_completions() {
	timeout 10 zsh -f "$harness" "$1" ||
		{ echo "Completion of '$1' failed with status $?" >&2; exit 1; }
}

result=$(list_completions 'pont ')
expected=$({
	./pont.sh -A
	./pont.sh -P | sed 's/^/+/'
	./pont.sh -T | sed 's/^/:/'
} | LC_ALL=C sort)
[ "$result" = "$expected" ] ||
	{ printf 'Completed:\n%s\nExpected:\n%s\n' "$result" "$expected"; exit 1; }

rc_home="$PONT_TARGET/rc_home"
mkdir -p "$rc_home/presets/sub" "$rc_home/modules/rc_one" \
	"$rc_home/modules/rc_two" "$XDG_CONFIG_HOME/pont"
: >"$rc_home/presets/sub/mypreset.set"
: >"$rc_home/presets/decoy.preset"
printf 'rc_tag # comment\r\n\nrc_last' >"$rc_home/modules/rc_one/.tags"
printf 'rc_other\n' >"$rc_home/modules/rc_two/.tags"
printf '%s\n' "PONT_MODULES_HOME='$rc_home/modules'" \
	"PONT_PRESETS_HOME='$rc_home/presets'" "PONT_PRESET_EXTENSION='.set'" \
	>"$XDG_CONFIG_HOME/pont/pontrc"
unset PONT_MODULES_HOME PONT_PRESETS_HOME
expected='+mypreset
:rc_last
:rc_other
:rc_tag
rc_one
rc_two'
result=$(list_completions 'pont ')
[ "$result" = "$expected" ] ||
	{ printf 'Completed with the pontrc:\n%s\n' "$result"; exit 1; }

result=$(
	PATH=${PATH#"$bin:"}
	PONT_SCRIPT="$PWD/pont.sh"
	# shellcheck disable=SC2016,SC2089
	COMPLETE_SETUP='pont() { "$PONT_SCRIPT" "$@"; }'
	# shellcheck disable=SC2090
	export PONT_SCRIPT COMPLETE_SETUP
	list_completions 'pont +'
)
[ "$result" = "+mypreset" ] ||
	{ echo "Completed with pont as a function: $result"; exit 1; }
