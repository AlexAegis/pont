#!/bin/sh
#                                  /$$
#                                 | $$
#   /$$$$$$   /$$$$$$  /$$$$$$$  /$$$$$$
#  /$$__  $$ /$$__  $$| $$__  $$|_  $$_/
# | $$  \ $$| $$  \ $$| $$  \ $$  | $$
# | $$  | $$| $$  | $$| $$  | $$  | $$ /$$
# | $$$$$$$/|  $$$$$$/| $$  | $$  |  $$$$/
# | $$____/  \______/ |__/  |__/   \___/
# | $$
# | $$
# |__/
#
#                - The dotmodule manager
#
# Copyright (c) 2020 Győri Sándor (AlexAegis) <alexaegis@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# Make all the variables (except IFS) in this script available to the subshells
set -a

is_installed() {
	# explicit check of wsl and systemd pairings
	if [ "$1" = "systemctl" ] && [ "$wsl" ]; then
		return 1
	fi
	command -v "$1" 2>/dev/null 1>/dev/null
}

get_home() {
	# This solution returns the home folder of the original invoker of sudo
	if is_installed getent; then
		getent passwd "${SUDO_USER-$USER}" | cut -d: -f6
	else
		# On MINGW getent is not available, but elevated privileges don't
		# change the home folder either, so this should be enough
		echo "$HOME"
	fi
}

# Environment
user_home=$(get_home)
uname_result="$(uname -s)"

case "${uname_result}" in
    Linux*)                        os_type="linux";;
    Darwin*)                       os_type="mac";;
	CYGWIN*|MINGW32*|MSYS*|MINGW*) os_type="windows";;
	FreeBSD*)                      os_type="freebsd";;
    *)                             os_type="unknown:${uname_result}"
esac

# Normalize XDG variables according to the spec (Set it only if absent)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$user_home/.config"}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$user_home/.cache"}
XDG_DATA_HOME=${XDG_DATA_HOME:-"$user_home/.local/share"}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"$user_home/.cache/run"}
XDG_BIN_HOME=${XDG_BIN_HOME:-"$user_home/.local/bin"}

# Environmental config
## This where the packages will be stowed to. Can also be set with -t
PONT_TARGET=${PONT_TARGET:-"$user_home"}
DOTFILES_HOME=${DOTFILES_HOME:-"$user_home/.config/dotfiles"}
# TODO: Support multiple folders $IFS separated, quote them
PONT_MODULES_HOME=${PONT_MODULES_HOME:-"$DOTFILES_HOME/modules"}
PONT_PRESETS_HOME=${PONT_PRESETS_HOME:-"$DOTFILES_HOME/presets"}
PONT_TEMPLATE_HOME=${PONT_TEMPLATE_HOME:-"$DOTFILES_HOME/template"}

# Config
PONT_LOG_LEVEL=1
PONT_CONFIG_FLAG=0
PONT_DRY_FLAG=0
PONT_FORCE_FLAG=0
PONT_NO_BASE_FLAG=0
PONT_ROOT_FLAG=1
PONT_SCRIPTS_ENABLED=1
PONT_MAKE_ENABLED=1
PONT_PRESET_EXTENSION=".preset"
PONT_HASHFILE_NAME=".tarhash"
PONT_DEPRECATIONFILE_NAME=".deprecated"
PONT_DEPENDENCIESFILE_NAME=".dependencies"
PONT_CONDITIONFILE_NAME=".condition"
PONT_CLASHFILE_NAME=".clash"
PONT_TAGSFILE_NAME=".tags"
PONT_DEFAULT_EXPANSION_ACTION="action_expand_none"
PONT_CLEAN_SYMLINKS=0
PONT_FIX_PERMISSIONS=0

HASH_COMMAND=
if is_installed sha1sum; then
	HASH_COMMAND="sha1sum"
elif is_installed shasum; then
	HASH_COMMAND="shasum"
fi

if [ -z "$HASH_COMMAND" ]; then
	echo 'No hasher available: sha1sum or shasum' >&2
	exit 1
fi

## Precalculated environmental variables for modules

# OS
linux=$(if [ "$os_type" = "linux" ]; then echo 1; fi)
export linux
mac=$(if [ "$os_type" = "mac" ]; then echo 1; fi)
export mac
windows=$(if [ "$os_type" = "windows" ]; then echo 1; fi)
export windows
bsd=$(if [ "$os_type" = "freebsd" ]; then echo 1; fi)
export bsd

wsl=$(if grep -qEi "(Microsoft|WSL)" /proc/version \
	2>/dev/null 1>/dev/null; then echo 1; fi)
export wsl
# wsl is always headless, others should be configured in pontrc
headless=$wsl
export headless
# Package manager
pacman=$(if is_installed pacman; then echo 1; fi)
export pacman
apt=$(if is_installed apt; then echo 1; fi)
export apt
xbps=$(if is_installed xbps; then echo 1; fi)
export xbps
emerge=$(if is_installed emerge; then echo 1; fi)
export emerge
# Init system
sysctl=$(if is_installed sysctl; then echo 1; fi)
export sysctl
systemctl=$(if is_installed systemctl; then echo 1; fi)
export systemctl
systemd=$systemctl # alias
export systemd
openrc=$(if is_installed rc-service; then echo 1; fi)
export openrc
# other features
if is_installed ldd; then
	pam=$(if ldd /bin/su | grep -q pam; then echo 1; fi)
fi
export pam
# Distribution
# ! May not be available on some systems
distribution=$(grep "^NAME" /etc/os-release 2>/dev/null | grep -oh "=.*" | \
	tr -d '="')
export distribution
# It uses if and not && because when using && a new line would
# return on false evaluation. `If` captures the output of test
arch=$(if [ "$distribution" = 'Arch Linux' ]; then echo 1; fi)
export arch
gentoo=$(if [ "$distribution" = 'Gentoo' ]; then echo 1; fi)
export gentoo
void=$(if [ "$distribution" = 'Void Linux' ]; then echo 1; fi)
export void
debian=$(if [ "$distribution" = 'Debian GNU/Linux' ]; then echo 1; fi)
export debian
ubuntu=$(if [ "$distribution" = 'Ubuntu' ]; then echo 1; fi)
export ubuntu
fedora=$(if [ "$distribution" = 'Fedora' ]; then echo 1; fi)
export fedora

# Config file sourcing
# shellcheck disable=SC1090
[ -e "$XDG_CONFIG_HOME/pont/pontrc" ] && . "$XDG_CONFIG_HOME/pont/pontrc"
# shellcheck disable=SC1090
[ -e "$XDG_CONFIG_HOME/pontrc" ] && . "$XDG_CONFIG_HOME/pontrc"
# shellcheck disable=SC1090
[ -e "$user_home/.pontrc" ] && . "$user_home/.pontrc"
# shellcheck disable=SC1091
[ -e "./.pontrc" ] && . "./.pontrc"

set +a

# Inner variables that are not allowed to be changed using pontrc
all_modules=
all_presets=
all_installed_modules=
all_outdated_modules=
all_deprecated_modules=
all_tags=
yank_target=
resolved=
expanded_presets=
entries_selected=
final_module_list=
expand_abstract_only=

# Newline separated list of actions. Used to preserve order of flags
execution_queue=

## Internal functions

is_deprecated() {
	# TODO: Implement conditional deprecation
	[ -e "$PONT_MODULES_HOME/$1/$PONT_DEPRECATIONFILE_NAME" ]
}

module_exists() {
	[ ! "$all_modules" ] && get_all_modules
	echo "$all_modules" | grep -x "$1"
}

get_all_modules() {
	all_modules=$(find "$PONT_MODULES_HOME/" -maxdepth 1 -mindepth 1 \
		-type d | sed 's|.*/||' | sort)
}

get_all_presets() {
	all_presets=$(find "$PONT_PRESETS_HOME/" -mindepth 1 \
		-type f -name '*.preset' | sed -e 's|.*/||' -e 's/.preset//' | sort)
}

get_all_installed_modules() {
	#shellcheck disable=SC2016
	all_installed_modules=$(grep -lm 1 -- "" \
		"$PONT_MODULES_HOME"/**/$PONT_HASHFILE_NAME | \
		sed -r 's_^.*/([^/]*)/[^/]*$_\1_g' | sort)
}

echo_all_outdated_modules() {
	[ ! "$all_modules" ] && get_all_modules
	for mod in $all_modules; do
		if [ -e "$PONT_MODULES_HOME/$mod/$PONT_HASHFILE_NAME" ]; then
			fresh_hash="$(do_hash "$mod")"
			old_hash="$(cat "$PONT_MODULES_HOME/$mod/$PONT_HASHFILE_NAME")"
			[ "$fresh_hash" != "$old_hash" ] && echo "$mod"
		fi
	done
}

get_all_outdated_modules() {
	all_outdated_modules=$(echo_all_outdated_modules)
}

get_all_deprecated_modules() {
	#shellcheck disable=SC2016
	all_deprecated_modules=$(find "$PONT_MODULES_HOME"/*/ -maxdepth 1 \
		-mindepth 1 -type f -name "$PONT_DEPRECATIONFILE_NAME" | \
		sed -r 's_^.*/([^/]*)/[^/]*$_\1_g' | sort)
}

get_all_tags() {
	all_tags=$(find "$PONT_MODULES_HOME"/*/ -maxdepth 1 -mindepth 1 \
		-type f -name '.tags' -exec cat {} + | \
		sed -e 's/ *#.*$//' -e '/^$/d' | sort | uniq)
}

rename_module() {
	# $1 from
	# $2 to
	log_info "Rename module $1 to $2"
	# TODO: Check if from exists, fail if not
	# TODO: Check if to exists, fail if is
	# TODO: Rename module folder,
	# TODO: Rename all packages ending inside it
	# TODO: rename all references in dependency files, presets
	# TODO: expand it to tags and presets
	# TODO: reinstall if it was installed
	echo "Not implemented!"
}

# Unused, left here for reference
# dequeue() {
# 	# remove last or remove the supplied items
# 	if [ ! "$1" ]; then
# 		execution_queue=$(echo "$execution_queue" | sed '$ d')
# 		return
# 	fi
# 	while :; do
# 		[ "$1" ] || break
# 		execution_queue=$(echo "$execution_queue" | grep -v "$1")
# 		shift
# 	done
# }

enqueue() {
	log_trace "Enqueuing $*"
	while :; do
		[ "$1" ] || break
		if [ "$execution_queue" ]; then
			execution_queue="${execution_queue}${IFS:-\0}${1}"
		else
			execution_queue="${1}"
		fi
		shift
	done
}

# Unused, left here for reference
# enqueue_front() {
# 	log_trace "Enqueuing to the front $*"
# 	while :; do
# 		[ "$1" ] || break
# 		if [ "$execution_queue" ]; then
# 			execution_queue="${1}${IFS:-\0}${execution_queue}"
# 		else
# 			execution_queue="${1}"
# 		fi
# 		shift
# 	done
# }

# Logging, the default log level is 1 meaning only trace logs are omitted
log_trace() {
	# Visible at and under log level 0
	[ "${PONT_LOG_LEVEL:-1}" -le 0 ] && \
		echo "${C_CYAN}[  Trace  ]: $*${C_RESET}" >&2
}

log_info() {
	# Visible at and under log level 1
	[ "${PONT_LOG_LEVEL:-1}" -le 1 ] && \
		echo "${C_BLUE}[  Info   ]: $*${C_RESET}" >&2
}

log_warning() {
	# Visible at and under log level 2
	[ "${PONT_LOG_LEVEL:-1}" -le 2 ] && \
		echo "${C_YELLOW}[ Warning ]: $*${C_RESET}" >&2
}

log_success() {
	# Visible at and under log level 2, same as warning but green
	[ "${PONT_LOG_LEVEL:-1}" -le 2 ] && \
		echo "${C_GREEN}[ Success ]: $*${C_RESET}" >&2
}

log_error() {
	# Visible at and under log level 3
	[ "${PONT_LOG_LEVEL:-1}" -le 3 ] && \
		echo "${C_RED}[  Error  ]: $*${C_RESET}" >&2
}

show_help() {
	echo "$(show_version)
-h, --help                    -- Print information on usage and flags then
                                 exit
-V, --version                 -- Print script version then exit
-l <LOGLEVEL>,
--log <LOGLEVEL>,
--log-level <LOGLEVEL>,       -- set log level, possible values are:
                                 0, trace, TRACE
                                 1, info, INFO
                                 2, warning, WARNING, success, SUCCESS
                                 3, error, ERROR
                                 4, none, NONE
                                	each option in a line mean the same thing
-v, --verbose                 -- log level 0 (trace)
-q, --quiet                   -- log level 3 (error)
-I, --list-installed          -- List all installed modules then exit
-A, --list-modules            -- List all modules then exit
-D, --list-deprecated         -- List all deprecated modules then exit
-P, --list-presets            -- List all presets then exit
-T, --list-tags               -- List all tags then exit
-E, --list-environment        -- List the config environment then exit
-L, --list-install            -- List the resolved final module list then exit
-Q, --list-queue              -- List the execution queue then exit
-O, --list-outdated           -- List all outdated (installed but has hash
                                 mismatch) modules then exit
-C, --toggle-clean-symlinks   -- Removes broken symlinks in the target
                                 directory. (By default it turns on the
                                 feautre, but if it was turned on by
                                 the environment it turns it off.)
-X, --toggle-fix-permissions  -- Adds user execute permissions to all module
                                 scripts before running them.
-p, --pull-dotfiles           -- Perform git pull on the dotfiles home folder
-u, --update                  -- Run all scrips starting with u in the
                                 selected modules.
-x, --execute, --install      -- Run init scripts, stow configs, then run
                                 scripts starting with a number and the
                                 Makefile in all the selected modules.
-r, --remove                  -- Unstows every stow package in the selected
                                 modules. If this flag is added twice it will
                                 also run all scrips starting with r in the
                                 selected modules.
-n, --expand-none             -- Expands only the abstract entries in the
                                 selection. No dependencies are resolved.
-e, --expand-seleted          -- Expands the original selection (the
                                 argument list) down to its dependencies
                                 recursively. Use this for regular
                                 installations.
-a, --expand-all              -- Expands every module regardless of the
                                 current selection.
-i, --expand-installed        -- Expands every installed module regardless
                                 of the current selection. Useful for batch
                                 running update and backup scripts.
-o, --expand-outdated         -- Expands every installed module regardless
                                 of the current selection thats saved hash
                                 is no longer matching a freshly calculated
                                 one. Useful for batch refreshing modules
                                 after modifying them.
-d, --dry                     -- Disables modifications. No stowing, no script
                                 execution. Useful for testing flag
                                 combinations.
-w, --wet                     -- Enabled modifications. Stowing, Script
                                 execution. On by default.
-b, --skip-base               -- Skip the base modules when expanding selection
                                 (Only useful before the -e flag).
-f, --force                   -- Ignores hashfiles. To avoid accidentally
                                 installing large dependency trees, this
                                 automatically turns on --expand-none.
                                 Expansion can be changed after.
-c --config                   -- Instead of the selection in the argument
                                 list, select entries in a TUI with whiptail.
--root                        -- Enables root privileged script execution.
                                 On by default.
-R, --skip-root               -- Disables root privileged script execution.
-s, --scripts                 -- Enables script execution. On by default.
-S, --skip-scripts            -- Disables script execution. Its like dry
                                 execution but with stowing enabled.
-m, --make                    -- Enables Makefile execution. On by default.
-M, --skip-make               -- Disables Makefile execution.
-t <DIR>, --target <DIR>      -- Its value will specify PONT_TARGET for this
                                 execution.
--scaffold, --cpt             -- Instead of executing modules, the selection
                                 now will used to scaffold modules based on a
                                 template folder at PONT_TEMPLATE_HOME
-y <DIR>, --yank <DIR>        -- will yank the selection (with none expansion
                                 by default) to the target folder. Useful for
                                 copying modules along with their
                                 dependencies. (Used presets are also copied!)
-Y <DIR>, --yank-expanded <DIR> -- will yank the expanded selection
                                   (same as -ey) to the target folder.

Some scenarios:

- Update all installed modules

    pont -iu

    # Expand installed modules, update them

- Reinstall all modified modules after a editing a lot of them

    pont -ox

    # Expand outdated modules, execute them

- Safe force. Install dependencies of the selection on demand
  and then force install the selection

    pont -exfx zsh

    # expand, execute, force (select none), execute
"
	exit 0
}

show_version() {
	echo "pont version: 0.9.0" && exit 0
}

clean_symlinks() {
	# recusively removes every broken symlink in a directory
	# used to clean before installation and after uninstallation
	find "${1-$PWD}" -type l -exec \
		sh -c 'for x; do [ -e "$x" ] || rm "$x"; done' _ {} +
}

scaffold() {
	# TODO scaffold
	# cpt template and pont --scaffold command to create from template
	# Use the remaining inputs as module folders to scaffold using cpt
	# If cpt is not available then try install it with cargo first
	# If no cargo is available then prompt the user to install it
	log_info "Scaffolding module $1 using cpt and $PONT_TEMPLATE_HOME \
as the template"
}

# Listings

action_list_execution_queue() {
	log_trace "Listing execution queue:"
	echo "$execution_queue"
}

action_list_installed_modules() {
	log_trace "All installed modules:"
	[ ! "$all_installed_modules" ] && get_all_installed_modules
	echo "$all_installed_modules"
}

action_list_deprecated() {
	log_trace "All deprecated modules:"
	[ ! "$all_deprecated_modules" ] && get_all_deprecated_modules
	echo "$all_deprecated_modules"
}

action_list_modules() {
	log_trace "All available modules:"
	[ ! "$all_modules" ] && get_all_modules
	echo "$all_modules"
}

action_list_presets() {
	log_trace "All available presets:"
	[ ! "$all_presets" ] && get_all_presets
	echo "$all_presets"
}

action_list_tags() {
	log_trace "All available tags:"
	[ ! "$all_tags" ] && get_all_tags
	echo "$all_tags"
}

action_list_outdated() {
	log_trace "Listing outdated modules:"
	[ ! "$all_outdated_modules" ] && get_all_outdated_modules
	echo "$all_outdated_modules"
}

action_list_environment() {
	log_info "All configurable variables:"
	echo "PONT_DRY_FLAG=${PONT_DRY_FLAG:-0}" \
		"PONT_FORCE_FLAG=${PONT_FORCE_FLAG:-0}" \
		"PONT_ROOT_FLAG=${PONT_ROOT_FLAG:-1}" \
		"PONT_CONFIG_FLAG=${PONT_CONFIG_FLAG:-0}" \
		"PONT_PRESET_EXTENSION=$PONT_PRESET_EXTENSION" \
		"PONT_HASHFILE_NAME=$PONT_HASHFILE_NAME" \
		"PONT_DEPENDENCIESFILE_NAME=$PONT_DEPENDENCIESFILE_NAME" \
		"PONT_CLASHFILE_NAME=$PONT_CLASHFILE_NAME" \
		"PONT_TAGSFILE_NAME=$PONT_TAGSFILE_NAME" \
		"PONT_DEFAULT_EXPANSION_ACTION=$PONT_DEFAULT_EXPANSION_ACTION" \
		"wsl=$wsl" \
		"headless=$headless" \
		"pacman=$pacman" \
		"emerge=$emerge" \
		"apt=$apt" \
		"xbps=$xbps" \
		"sysctl=$sysctl" \
		"systemctl=$systemctl" \
		"systemd=$systemd" \
		"openrc=$openrc" \
		"distribution=$distribution" \
		"arch=$arch" \
		"gentoo=$gentoo" \
		"void=$void" \
		"debian=$debian" \
		"ubuntu=$ubuntu" \
		"fedora=$fedora" && exit 0
}

action_list_modules_to_execute() {
	# Print the to-be installed modules
	log_info "List modules to execute:"
	echo "$final_module_list"
}

## Argument handling

expand_single_args() {
	var="${1#-}" # cut off first, and only dash
	while [ "$var" ]; do
		next="${var#?}"
		first_char="${var%$next}"
		echo "-$first_char"
		var="$next" # next
	done
}

# POSIX compliant argument parser.
# This function will parse and return a separated argument list. It handles
# long arguments and checks for missing or extra values.
# it handles both whitespace and '=' separated values
# it also treats quoted parameters as one
# It does NOT check for unknown variables as there is no list of allowed args
# but those are easy to handle later
parse_args() {
	# first parameter is a single string, an IFS separated list of arguments
	# that should have a single value
	with_parameters="$1"
	shift
	while [ "$1" ]; do
		single_cut_with_equalparam="${1##-}"
		single_cut="${single_cut_with_equalparam%%=*}" # = value cut pff
		double_cut_with_equalparam="${1##--}"
		double_cut="${double_cut_with_equalparam%%=*}" # = value cut pff
		equalparam=${1##*=}
		if [ "$equalparam" = "$1" ]; then
			equalparam=''
		fi
		# starts with one dash but not two
		if ! [ "$single_cut_with_equalparam" = "$1" ] && [ "$double_cut_with_equalparam" = "$1" ]; then
			split_args=$(expand_single_args "$single_cut")
			shift
			if [ -n "$equalparam" ]; then
				set -- "$equalparam" "$@"
			fi
			# shellcheck disable=SC2086
			set -- $split_args "$@"
		# two dash
		elif ! [ "$double_cut_with_equalparam" = "$1" ]; then
			shift
			if [ -n "$equalparam" ]; then
				set -- "$equalparam" "$@"
			fi
			set -- "--$double_cut" "$@"
		fi

		has_parameter=''
		for a in $with_parameters; do
			if [ "$a" = "$1" ]; then
				has_parameter='1'
				break
			fi
		done

		if [ -n "$has_parameter" ]; then
			if [ -z "$2" ] || ! [ "${2##-}" = "$2" ]; then
				echo "$1 is missing it's parameter!" >&2
				exit 1
			fi
		fi

		printf "%s\n\n" "$1"
		shift
	done
}

_args_with_params='-l
--log-level
-t
--target
-y
--yank
-Y
--yank-expanded
--rename
'
# TODO: --rename second argument is not handled

interpret_args() {
	while [ "$1" ]; do
		case $1 in
			-h | -\? | --help) show_help ;;
			-V | --version) show_version ;;
			-l | --log | --log-level)
				case $2 in
					'trace' | 'TRACE' | '0') PONT_LOG_LEVEL='0' ;;
					'info' | 'INFO' | '1') PONT_LOG_LEVEL='1' ;;
					'warning' | 'WARNING' | '2') PONT_LOG_LEVEL='2' ;;
					'success' | 'SUCCESS') PONT_LOG_LEVEL='2' ;;
					'error' | 'ERROR' | '3') PONT_LOG_LEVEL='3' ;;
					'none' | 'NONE' | '4') PONT_LOG_LEVEL='4' ;;
					*) log_error "Invalid loglevel: $2"; exit 1 ;;
				esac
				shift
				;;
			-v | --verbose)	PONT_LOG_LEVEL=0 ;; # Log level trace
			-q | --quiet) PONT_LOG_LEVEL=3 ;; # Log level error
			-I | --list-installed) action_list_installed_modules; exit 0 ;;
			-A | --list-modules) action_list_modules; exit 0 ;;
			-D | --list-deprecated) action_list_deprecated; exit 0 ;;
			-P | --list-presets) action_list_presets; exit 0 ;;
			-T | --list-tags) action_list_tags; exit 0 ;;
			-E | --list-environment) action_list_environment; exit 0 ;;
			-L | --list-install) enqueue "action_list_modules_to_install" ;;
			-Q | --list-queue) action_list_execution_queue; exit 0 ;;
			-O | --list-outdated) action_list_outdated; exit 0 ;;
			-C | --toggle-clean-symlinks)
				PONT_CLEAN_SYMLINKS=$((1-PONT_CLEAN_SYMLINKS)) ;;
			-X | --toggle-fix-permissions)
				PONT_FIX_PERMISSIONS=$((1-PONT_FIX_PERMISSIONS)) ;;
			-p | --pull-dotfiles)
				enqueue "pull_dotfiles" ;;
			-u | --update) enqueue "action_expand_default_if_not_yet" \
				"action_update_modules" ;;
			-x | --execute | --install) enqueue \
				"action_expand_default_if_not_yet" "action_execute_modules" ;;
			-r | --remove) # behaves differently when called multiple times
				remove_count=$((${remove_count:-0} + 1))
				[ ${remove_count:-0} = 1 ] && \
					enqueue "action_expand_default_if_not_yet" \
							"action_remove_modules" ;;
			-n | --expand-none) enqueue "action_expand_none" ;;
			-e | --expand-selected) enqueue "action_expand_selected" ;;
			-a | --expand-all) enqueue "action_expand_all" ;;
			-i | --expand-installed) enqueue "action_expand_installed" ;;
			-o | --expand-outdated) enqueue "action_expand_outdated" ;;
			-d | --dry) PONT_DRY_FLAG=1 ;;
			-w | --wet) PONT_DRY_FLAG=0 ;;
			-b | --skip-base) PONT_NO_BASE_FLAG=1 ;;
			-f | --force) PONT_FORCE_FLAG=1; enqueue "action_expand_none" ;;
			-c | --config) PONT_CONFIG_FLAG=1 ;;
			--root) PONT_ROOT_FLAG=1 ;;
			-R | --skip-root) PONT_ROOT_FLAG=0 ;;
			-s | --scripts) PONT_SCRIPTS_ENABLED=1 ;;
			-S | --skip-scripts) PONT_SCRIPTS_ENABLED=0 ;;
			-m | --make) PONT_MAKE_ENABLED=1 ;;
			-M | --skip-make) PONT_MAKE_ENABLED=0 ;;
			-t | --target) # package installation target
				if [ -d "$2" ]; then
					PONT_TARGET="$2"
				else
					log_error "Invalid target: $2"; exit 1
				fi
				shift
				;;
			--scaffold | --cpt) # Ask for everything
				shift
				scaffold "$@"
				exit 0
				;;
			-y | --yank)
				enqueue "action_expand_default_if_not_yet" "action_yank"
				if [ -d "$2" ]; then
					yank_target="$2"
				else
					log_error "Invalid target: $2"; exit 1
				fi
				echo "yank_target $yank_target"
				shift
				;;
			-Y | --yank-expanded)
				enqueue "action_expand_selected" "action_yank"
				if [ -d "$2" ]; then
					yank_target="$2"
				else
					log_error "Invalid target: $2"; exit 1
				fi
				shift
				;;
			--rename)
				shift
				rename_module "$2" "$3"
				exit 0
				;;
			--)	;;
			-?*) log_error "Unknown option (ignored): $1";;
			*) # The rest are selected modules
				# TODO: Pre validate them
				if [ "$1" ]; then
					if [ "$entries_selected" ]; then
						entries_selected="$entries_selected${IFS:-\0}$1"
					else
						entries_selected="$1"
					fi
					log_trace "Initially selected:
$entries_selected"
				else
					break
				fi
				;;
		esac
		shift
	done
}

trim_around() {
	# removes the first and last characters from every line
	last_removed=${$1::-1}
	echo ${last_removed:1}
}

has_tag() {
	# Returns every dotmodule that contains any of the tags
	# shellcheck disable=SC2016
	grep -lRxEm 1 -- "$1 ?#?.*" \
		"$PONT_MODULES_HOME"/*/"$PONT_TAGSFILE_NAME" |
		sed -r 's_^.*/([^/]*)/[^/]*$_\1_g'
}

in_preset() {
	# returns every entry in a preset
	find "$PONT_PRESETS_HOME" -mindepth 1 -name "$1$PONT_PRESET_EXTENSION" \
		-type f -print0 | xargs -0 sed -e 's/ *#.*$//' -e '/^$/d'
}

get_clashes() {
	if [ -f "$PONT_MODULES_HOME/$1/$PONT_CLASHFILE_NAME" ]; then
		sed -e 's/ *#.*$//' -e '/^$/d' \
			"$PONT_MODULES_HOME/$1/$PONT_CLASHFILE_NAME"
	fi
}

get_dependencies() {
	if [ -f "$PONT_MODULES_HOME/$1/$PONT_DEPENDENCIESFILE_NAME" ]; then
		sed -e 's/ *#.*$//' -e '/^$/d' \
			"$PONT_MODULES_HOME/$1/$PONT_DEPENDENCIESFILE_NAME"
	fi
}

get_entry() {
	echo "$1" | cut -d '?' -f 1 | cut -d '#' -f 1 | sed 's/ $//'
}

get_condition() {
	echo "$1" | cut -d '?' -s -f 2- | cut -d '#' -f 1  | sed 's/^ //'
}

pull_dotfiles() {
	log_trace "Performing git pull on DOTFILES_HOME ($DOTFILES_HOME)"
	if [ -d "$DOTFILES_HOME/.git" ]; then
		(
			cd "$DOTFILES_HOME" || exit 1
			git pull
		)
	else
		log_error "DOTFILES_HOME ($DOTFILES_HOME) is not a git folder"
	fi
}

execute_scripts_for_module() {
	# 1: module name
	# 2: scripts to run
	# 3: sourcing setting, if set, user privileged scripts will be sourced
	cd "$PONT_MODULES_HOME/$1" || exit 1
	group_result=0
	successful_scripts=0
	for script in $2; do
		result=0
		if [ ${PONT_DRY_FLAG:-0} = 0 ] && \
			[ ${PONT_SCRIPTS_ENABLED:-1} = 1 ]; then
			log_trace "Running $script..."

			privilege='user'
			[ "$(echo "$script" | grep -o '\.' | wc -w)" -gt 1 ] && \
				privilege=$(echo "$script" | cut -d '.' -f 2 | sed 's/-.*//')

			if [ "$privilege" = "root" ] ||
				[ "$privilege" = "sudo" ]; then
				if [ "${PONT_ROOT_FLAG:-1}" = 1 ]; then
					(
						sudo --preserve-env="PATH" -E \
							"$PONT_MODULES_HOME/$1/$script"
					)
				else
					log_info "Skipping $script because root execution" \
						"is disabled"
				fi
			else
				if [ "$SUDO_USER" ]; then
					(
						sudo --preserve-env="PATH" -E \
							-u "$SUDO_USER" "$PONT_MODULES_HOME/$1/$script"
					)
				else
					if [ "$3" ]; then
						set -a
						# shellcheck disable=SC1090
						. "$PONT_MODULES_HOME/$1/$script"
						set +a
					else
						(
							"$PONT_MODULES_HOME/$1/$script"
						)
					fi
				fi
			fi
			result=$?
			group_result=$((group_result + result))
			if [ $result = 0 ]; then
				successful_scripts=$((successful_scripts + 1))
			fi
		else
			log_trace "Skipping $script..."
		fi
	done
}

do_expand_entries() {
	while :; do
		[ "$1" ] || break
		# Extracting condition, if there is
		condition="$(get_condition "$1")"
		# TODO: .condition files and $HEADLESS variable
		log_trace "Trying to expand $(get_entry "$1")..."

		[ "$condition" ] && log_trace "...with condition $condition..."

		if ! eval "$condition"; then
			log_info "Condition ($condition) for $1 did not met, skipping"
			shift
			continue
		fi

		log_trace "Already resolved entries are: $resolved"
		if [ "$(echo "$resolved" | grep -x "$1")" = "" ]; then
			if [ -z "$resolved" ]; then
				resolved="$1"
			else
				resolved="$resolved${IFS:-\0}$1"
			fi
			case "$1" in
			+*) # presets
				# collect expanded presets in case a yank action needs it
				if [ -z "$expanded_presets" ]; then
					expanded_presets="$1"
				else
					expanded_presets="$expanded_presets${IFS:-\0}$1"
				fi
				# shellcheck disable=SC2046
				do_expand_entries \
					$(in_preset "$(get_entry "$1" | cut -c2-)")
				;;
			:*) # tags
				# shellcheck disable=SC2046
				do_expand_entries \
					$(has_tag "$(get_entry "$1" | cut -c2-)")
				;;
			*) # modules
				# shellcheck disable=SC2046
				if [ "${expand_abstract_only:-0}" = 0 ]; then
					do_expand_entries \
						$(get_dependencies "$(get_entry "$1")")
				fi
				get_entry "$1"
				;;
			esac
			log_trace "...done resolving $1"
		else
			log_trace "...already resolved $1"
		fi
		shift
	done
}

expand_entries() {
	final_module_list="$(do_expand_entries "$@")"
}

expand_abstract_entries() {
	expand_abstract_only=1
	final_module_list="$(do_expand_entries "$@")"
	expand_abstract_only=
}

init_modules() {
	log_info "Initializing modules $*"
	while :; do
		[ "$1" ] || break
		init_sripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
			-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' \
			| grep '^i.*\..*\..*$' | sort)
		execute_scripts_for_module "$1" "$init_sripts_in_module" "1"
		shift
	done
}

source_modules_envs() {
	log_info "Sourcing modules envs $*"
	while :; do
		[ "$1" ] || break
		env_sripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
			-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' \
			| grep '^e.*\..*\..*$' | sort)
		log_trace "Environmental scripts in $1 are $env_sripts_in_module"
		execute_scripts_for_module "$1" "$env_sripts_in_module" "1"
		shift
	done
}

update_modules() {
	log_info "Updating modules $*"
	while :; do
		[ "$1" ] || break
		# Source env
		source_modules_envs "$1"
		update_sripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
			-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' \
			| grep '^u.*\..*\..*$' | sort)
		execute_scripts_for_module "$1" "$update_sripts_in_module"
		shift
	done
}

remove_modules() {
	log_trace "Removing modules $*"
	while :; do
		[ "$1" ] || break
		# Source env
		source_modules_envs "$1"
		# Only run the remove scripts with -rr, a single r just unstows
		if [ "$remove_count" -ge 2 ]; then
			log_info "Hard remove $1"
			remove_sripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
				-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' |
				grep -v '^restore.*$' | grep '^r.*\..*\..*$' | sort)
			execute_scripts_for_module "$1" "$remove_sripts_in_module"
		else
			log_info "Soft remove $1"
		fi

		# Stowing is hard disabled on windows
		if [ -z "$windows" ]; then
			unstow_modules "$1"
		fi

		# remove hashfile to mark as uninstalled
		[ -e "$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME" ] &&
			rm "$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME"

		shift
	done
}

do_stow() {
	# $1: the packages parent directory
	# $2: target directory
	# $3: package name
	# $4: stowmode  "stow" | "unstow"

	log_trace "Stowing package $3 to $2 from $1"

	if ! is_installed stow; then
		log_error "stow is not installed!"
		exit 1
	fi
	if [ ! -d "$1" ]; then
		log_error "package not found!
	$1
	$2
	$3"
		exit 1
	fi
	if [ "$2" ] && [ ! -d "$2" ]; then
		log_warning "target directory does not exist, creating!
	$1
	$2
	$3"
		mkdir -p "$2"
	fi
	if [ ! "$3" ]; then
		log_error "no package name!
	$1
	$2
	$3"
		exit 1
	fi

	if [ ${PONT_DRY_FLAG:-0} != 1 ]; then
		# Module target symlinks are always cleaned
		clean_symlinks "$2"
		if [ "$SUDO_USER" ]; then
			sudo --preserve-env="PATH" -E -u "$SUDO_USER" \
				stow -D -d "$1" -t "$2" "$3"
			[ "$stow_mode" = "stow" ] && \
				sudo --preserve-env="PATH" -E -u "$SUDO_USER" \
					stow -S -d "$1" -t "$2" "$3"
		else
			# https://github.com/aspiers/stow/issues/69
			stow -D -d "$1" -t "$2" "$3"
			[ "$stow_mode" = "stow" ] && \
				stow -S -d "$1" -t "$2" "$3"
		fi
		log_trace "Stowed $1"
	fi
}

stow_package() {
	# recieves a stowmode "stow" | "unstow"
	# then a list of directories of packages inside modules
	stow_mode="$1"
	log_trace "Stowing packages $*"
	shift
	while :; do
		[ "$1" ] || break

		if [ "$(basename "$1" | cut -d '.' -f 3)" ]; then
			stow_condition="$(basename "$1" | cut -d '.' -f 2)"
			if [ "${stow_condition#\$}" = "$stow_condition" ]; then
				log_trace "Stow condition $stow_condition is a command"
				is_installed "$stow_condition" || { shift; continue; }
			else
				log_trace "Stow condition $stow_condition is a variable"
				[ "$(eval "echo $stow_condition")" ] || { shift; continue; }
			fi
		fi

		log_trace "Do stowing $1"
		do_stow "$(echo "${1%/*}" | sed 's|^$|/|')" \
			"$(/bin/sh -c "echo \$$(basename "$1" | cut -d '.' -f 1)" | \
				sed -e "s|^\$$|$PONT_TARGET|" \
				-e "s|^[^/]|$PONT_TARGET/\0|")" \
			"$(basename "$1")" \
			"$stow_mode"
		shift
	done

}

stow_modules() {
	log_trace "Stow modules $*"
	while :; do
		[ "$1" ] || break
		# shellcheck disable=SC2046
		# TODO: Mixed splitting, find outputs new line splits
		stow_package "stow" $(find "$PONT_MODULES_HOME/$1" \
			-mindepth 1 -maxdepth 1 -type d -iname "*.$1")
		shift
	done
}

unstow_modules() {
	log_trace "Unstow modules $*"
	while :; do
		[ "$1" ] || break
		# shellcheck disable=SC2046
		stow_package "unstow" $(find "$PONT_MODULES_HOME/$1" \
			-mindepth 1 -maxdepth 1 -type d -iname "*.$1")
		shift
	done
}

make_module() {
	if [ ${PONT_MAKE_ENABLED:-1} = 1 ] \
		&& [ -e "$PONT_MODULES_HOME/$1/Makefile" ]; then
		if ! is_installed "make"; then
			log_error "Make not available"; return 1
		fi
		# It's already cd'd in.
		# Makefiles are always executed using user rights
		if [ "$SUDO_USER" ]; then
			sudo --preserve-env="PATH" -E -u "$SUDO_USER" make
		else
			make
		fi
	fi
}

powershell_script_filter() {
	if [ $windows ]; then
		grep "^.*ps1$"
	else
		grep -v "^.*ps1$"
	fi
}

get_install_scripts_in_module() {
	find "$PONT_MODULES_HOME/$1/" -mindepth 1 -maxdepth 1 \
		-type f 2>/dev/null | sed 's|.*/||' | grep "^[0-9].*\..*\..*$" |
		sort | powershell_script_filter
}

install_module() {
	sripts_in_module=$(get_install_scripts_in_module "$1")
	log_trace "Scripts in module for $1 are:
$sripts_in_module"
	groups_in_module=$(echo "$sripts_in_module" | sed 's/\..*//g' | uniq)
	for group in $groups_in_module; do
		group_scripts=$(echo "$sripts_in_module" | grep "^${group}..*$" )
	 	group_scripts_to_run=
		for script in $group_scripts; do
			# at least 4 section long, so there is a condition
			if [ "$(echo "$script" | cut -d '.' -f 4)" ]; then
				script_condition="$(echo "$script" | cut -d '.' -f 3)"
				if [ "$script_condition" = "fallback" ]; then
					log_trace "fallback script"
					group_scripts_to_run="$group_scripts_to_run\
${IFS:-\0}$script"
				elif [ "${script_condition#\$}" = "$script_condition" ]; then
					log_trace "condition $script_condition is a command"
					is_installed "$script_condition" && \
						group_scripts_to_run="$group_scripts_to_run\
${IFS:-\0}$script"
				else
					log_trace "condition $script_condition is a variable"
					[ "$(eval "echo $script_condition")" ] && \
						group_scripts_to_run="$group_scripts_to_run\
${IFS:-\0}$script"
				fi
			else
				# else it has no condition
				group_scripts_to_run="$group_scripts_to_run${IFS:-\0}$script"
			fi
		done
		group_scripts_without_fallback=$(echo "$group_scripts_to_run" |
			 grep -v 'fallback')

		log_trace "scripts to execute after conditions
$group_scripts_without_fallback"

		execute_scripts_for_module "$1" "$group_scripts_without_fallback"

		group_fallback_scripts=$(echo "$group_scripts_to_run" |
			 grep 'fallback')
		if [ $successful_scripts = 0 ] && [ "$group_fallback_scripts" ]; then
			log_info "Installing group $group for $1 was not successful, \
trying fallbacks:
$group_fallback_scripts"

			execute_scripts_for_module "$1" "$group_fallback_scripts"
		fi

		total_result=$((total_result + group_result))
	done
}

do_hash() {
	tar --absolute-names \
		--exclude="$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME" \
		-c "$PONT_MODULES_HOME/$1" | "$HASH_COMMAND"
}

do_hash_module() {
	do_hash "$1" >"$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME"
}

hash_module() {
	if [ ${PONT_DRY_FLAG:-0} = 0 ]; then
		log_success "Successfully installed $1"

		if [ "$SUDO_USER" ]; then
			sudo --preserve-env="PATH" -E -u "$SUDO_USER" do_hash_module "$1"
		else
			do_hash_module "$1"
		fi
	fi
}

execute_modules() {
	while :; do
		[ "$1" ] || break
		total_result=0
		log_trace "Checking if module exists: $PONT_MODULES_HOME/$1"
		if [ ! -d "$PONT_MODULES_HOME/$1" ]; then
			log_error "Module $1 not found. Skipping"
			shift
			continue
		fi

		if [ -e "$PONT_MODULES_HOME/$1/$PONT_CONDITIONFILE_NAME" ] && \
			! eval "$(cat "$PONT_MODULES_HOME/$1/$PONT_CONDITIONFILE_NAME")"
		then
			log_warning "Condition on $1 failed. Skipping
$(cat "$PONT_MODULES_HOME/$1/$PONT_CONDITIONFILE_NAME")"
			shift
			continue
		fi

		log_info "Installing $1"

		# Only calculate the hashes if we going to use it
		if [ "${PONT_FORCE_FLAG:-0}" = 0 ]; then
			old_hash=$(cat "$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME" \
				2>/dev/null)
			new_hash=$(tar --absolute-names \
				--exclude="$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME" \
				-c "$PONT_MODULES_HOME/$1" | "$HASH_COMMAND")

			if [ "$old_hash" = "$new_hash" ]; then
				log_trace "${C_GREEN}hash match $old_hash $new_hash"
			else
				log_trace "${C_RED}hash mismatch $old_hash $new_hash"
			fi
		fi

		# Source env, regardless, so the environment of the dependencies
		# are available
		source_modules_envs "$1"

		if [ "${PONT_FORCE_FLAG:-0}" = 1 ] \
			|| [ "$old_hash" != "$new_hash" ]; then

			if [ "${PONT_FORCE_FLAG:-0}" != 1 ] && is_deprecated "$1";
				then
				log_warning "$1 is deprecated"
				shift
				continue
			fi

			if [ "${PONT_DRY_FLAG:-0}" = 1 ]; then
				log_trace "Dotmodule $1 would be installed"
			else
				log_trace "Applying dotmodule $1"
			fi

			init_modules "$1"

			# Stowing is hard disabled on windows
			if [ -z "$windows" ]; then
				stow_modules "$1"
			fi

			# Make isn't a separate step because there only
			# should be one single install step so that the hashes
			# and the result can be determined in a single step
			# It's mutually exclusive with normal scripts, will only run
			# When no numbered scripts exist
			if [ -z "$(get_install_scripts_in_module $1)" ];then
				make_module "$1"
			fi

			install_module "$1"

			if [ "$total_result" = 0 ]; then
				# Calculate fresh hash on success
				hash_module "$1"
			else
				log_error "Installation failed $1"
				[ -e "$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME" ] &&
					rm "$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME"
			fi

		else
			log_info "$1 is already installed and no changes are detected"
		fi
		shift
	done
}

## Actions

action_quit() {
	exit "${1:-0}"
}

action_fix_permissions() {
	# Fix permissions, except in submodules
	log_info "Fixing permissions in $DOTFILES_HOME... "
	subs=$(git submodule status | sed -e 's/^ *//' -e 's/ *$//')
	submodules=$(
		cd "$DOTFILES_HOME" || exit
		echo "${subs% *}" | cut -d ' ' -f 2- |
			sed -e 's@^@-not -path "**/@' -e 's@$@/*"@' | tr '\n' ' '
	)

	eval "find $PONT_MODULES_HOME -type f \( $submodules \) \
-regex '.*\.\(sh\|zsh\|bash\|fish\|dash\)' -exec chmod u+x {} \;"
}

action_clean_symlinks() {
	# Remove incorrect symlinks in PONT_TARGET
	clean_symlinks "$PONT_TARGET"
}

action_expand_selected() {
	log_info "Set final module list to every selected and expanded module"
	final_module_list=

	if [ "$PONT_NO_BASE_FLAG" != 1 ]; then
		old_ifs=$IFS
		IFS=' '
		for base_module in $PONT_BASE_MODULES; do
			IFS=$old_ifs
			entries_selected="${base_module}${IFS:-\0}${entries_selected}"
		done
		IFS=$old_ifs
	fi
	# shellcheck disable=SC2086
	expand_entries $entries_selected
	log_info "Final module list is:
$final_module_list"
}

action_expand_all() {
	log_info "Set final module list to every module, expanding them."
	final_module_list=
	[ ! "$all_modules" ] && get_all_modules
	# shellcheck disable=SC2086
	expand_entries $all_modules
	log_info "Final module list is:
$final_module_list"
}

action_expand_installed() {
	log_info "Set final module list to every installed and expanded module."
	final_module_list=
	[ ! "$all_installed_modules" ] && get_all_installed_modules
	# shellcheck disable=SC2086
	expand_entries $all_installed_modules
	log_info "Final module list is:
$final_module_list"
}

action_expand_outdated() {
	log_info "Set final module list to every installed, outdated module," \
			 "expanding them."
	final_module_list=
	[ ! "$all_outdated_modules" ] && get_all_outdated_modules
	# shellcheck disable=SC2086
	expand_entries $all_outdated_modules
	log_info "Final module list is:
$final_module_list"
}

action_expand_default_if_not_yet() {
	# If no expansion happened at this point, execute the default one
	[ ! "$final_module_list" ] && "$PONT_DEFAULT_EXPANSION_ACTION"
}

action_expand_none() {
	log_info "Set final module list only to the selected modules," \
			 "no dependency expansion."
	final_module_list=
	# shellcheck disable=SC2086
	expand_abstract_entries $entries_selected
	log_info "Final module list is:
$final_module_list"
}

action_list_modules_to_install() {
	log_info "List modules to install:"
	echo "$final_module_list"
}

action_remove_modules() {
	# shellcheck disable=SC2086
	remove_modules $final_module_list
}

action_execute_modules() {
	# shellcheck disable=SC2086
	execute_modules $final_module_list
}

action_update_modules() {
	# shellcheck disable=SC2086
	update_modules $final_module_list
}

do_yank() {
	mkdir -p "$yank_target"
	# Copy all modules
	while :; do
		[ "$1" ] || break
		log_info "Yanking $PONT_MODULES_HOME/$1 to $yank_target/$1"
		cp -r "$PONT_MODULES_HOME/$1" "$yank_target/$1"
		shift
	done
	# Copy all used presets
	for preset in $expanded_presets; do
		preset_file_name="$(echo "$preset" | cut -d '+' -f 2-).preset"
		cp "$(find "$PONT_PRESETS_HOME" -type f -name "$preset_file_name")" \
			"$yank_target/$preset_file_name"
	done
}

action_yank() {
	# shellcheck disable=SC2086
	do_yank $final_module_list
}

ask_entries() {
	! is_installed whiptail && log_error "No whiptail installed" \
		&& exit 1

	[ ! "$all_modules" ] && get_all_modules
	[ ! "$all_tags" ] && get_all_tags
	[ ! "$all_presets" ] && get_all_presets

	preset_options="$(echo "$all_presets" | \
		awk '{printf ":%s :%s OFF ", $1, $1}')"
	tag_options="$(echo "$all_tags" | \
		awk '{printf ":%s :%s OFF ", $1, $1}')"
	module_options="$(echo "$all_modules" | \
		awk '{printf "%s %s OFF ", $1, $1}')"

	log_trace "Manual module input"

	entries_selected=$(eval "whiptail --separate-output --clear --notags \
		--title 'Select modules to install' \
		--checklist 'Space changes selection, enter approves' \
		0 0 0 $preset_options $tag_options $module_options \
		3>&1 1>&2 2>&3 3>&- | sed 's/ /\n/g'")
}

execute_queue() {
	log_trace "executing queue: $*"
	for action in "$@"; do
		log_info "Executing: $action"
		$action
	done
}

## Execution

IFS='
'
# shellcheck disable=SC2046
interpret_args $(parse_args "$_args_with_params" "$@")

# if nothing is selected, ask for modules
if [ ${PONT_CONFIG_FLAG:-0} = 1 ] || [ $# -eq 0 ]; then
	ask_entries # config checked again to avoid double call on ask_entries
fi

# if nothing is in the execution queue, assume expand and execute
[ ! "$execution_queue" ] \
	 && enqueue "action_expand_selected" "action_execute_modules"

log_trace "Execution queue:
$execution_queue"

[ $PONT_FIX_PERMISSIONS = 1 ] && action_fix_permissions
# shellcheck disable=SC2086
execute_queue $execution_queue

[ $PONT_CLEAN_SYMLINKS = 1 ] && action_clean_symlinks

set +a
