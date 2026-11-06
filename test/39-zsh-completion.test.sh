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
	timeout 10 zsh -f "$harness" "$@" ||
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

folders="$PONT_TARGET/folders"
mkdir -p "$folders/one" "$folders/two"
: >"$folders/file"
ln -s one "$folders/link"
for line in 'pont -t ' 'pont -t=' 'pont -vt ' 'pont --target ' \
	'pont --target=' 'pont -y ' 'pont -y=' 'pont --yank=' 'pont -Y ' \
	'pont -Y=' 'pont --yank-expanded ' 'pont --yank-expanded='; do
	result=$(cd "$folders" && list_completions "$line")
	[ "$result" = "link
one
two" ] || { echo "Completed '$line' as: $result"; exit 1; }
done
for line in 'pont -l t' 'pont -l=t' 'pont -vl=t' 'pont --log=t' \
	'pont --log-level t' 'pont --log-level=t'; do
	result=$(list_completions "$line")
	[ "$result" = trace ] || { echo "Completed '$line' as: $result"; exit 1; }
done
expect_option() {
	result=$(list_completions "$1")
	case $result in
	*'
'* | '') echo "Completed '$1' as: $result"; exit 1 ;;
	"$2 "*) ;;
	*) echo "Completed '$1' as: $result"; exit 1 ;;
	esac
}
expect_option 'pont --expand-selected' --expand-selected
expect_option 'pont --yank-expanded' --yank-expanded
expect_option 'pont -\?' '-?'
expect_option 'pont -r --rem' --remove
expect_option 'pont --ren' --rename
expect_entries() {
	entries_line=$1
	entries_listed=$2
	shift 2
	result=$(list_completions "$entries_line")
	printf '%s\n' "$result" | grep -qx -e "$entries_listed" || {
		echo "Completed '$entries_line' without $entries_listed: $result"
		exit 1
	}
	for unlisted; do
		! printf '%s\n' "$result" | grep -qx -e "$unlisted" || {
			echo "Completed '$entries_line' with $unlisted: $result"
			exit 1
		}
	done
}
expect_entries 'pont -T' -v -T
expect_entries 'pont -h -' -v '-?'
expect_entries 'pont -? -' -v -h --help
result=$(
	# shellcheck disable=SC2089
	COMPLETE_SETUP="zstyle ':completion:*:descriptions' format '<LC><RC>%d<EC>'"
	# shellcheck disable=SC2090
	export COMPLETE_SETUP
	list_completions 'pont --rename '
)
[ "$result" = "module
rc_one
rc_two" ] || { echo "Completed 'pont --rename ' as: $result"; exit 1; }
result=$(list_completions 'pont --rename=')
[ "$result" = "rc_one
rc_two" ] || { echo "Completed 'pont --rename=' as: $result"; exit 1; }
for line in 'pont -t' 'pont -vt' 'pont -l' 'pont -y' 'pont -Y'; do
	result=$(cd "$folders" && list_completions "$line" --insert)
	[ "$result" = "$line X" ] ||
		{ echo "Inserted after '$line': $result"; exit 1; }
done
result=$(cd "$folders" && list_completions 'pont -to' --insert)
[ "$result" = 'pont -toX' ] ||
	{ echo "Inserted after 'pont -to': $result"; exit 1; }
for line in 'pont -t' 'pont -to' 'pont -vto' 'pont -lt' 'pont -yo' \
	'pont -Yo' 'pont --scaffold ' 'pont --cpt one ' 'pont --rename rc_one '; do
	result=$(cd "$folders" && list_completions "$line")
	[ -z "$result" ] || { echo "Completed '$line' as: $result"; exit 1; }
done
