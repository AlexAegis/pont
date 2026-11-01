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
# Copyright (c) 2020-2026 Győri Sándor (AlexAegis) <alexaegis@pm.me>
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
		getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6
	else
		# On MINGW getent is not available, but elevated privileges don't
		# change the home folder either, so this should be enough
		echo "$HOME"
	fi
}

# Same as sudo -E, but also works with sudo-rs, which ignores -E
sudo_with_environment() {
	case $(sudo --version 2>/dev/null) in
	sudo-rs*) sudo --preserve-env="$(sudo_kept_variables)" "$@" ;;
	*) sudo --preserve-env="PATH" -E "$@" ;;
	esac
}

# Exported variables that sudo -E would keep, as a comma-separated list. The
# patterns below are sudo's default env_delete and env_check lists, plus USER,
# LOGNAME and SUDO_*, which sudo sets itself.
sudo_kept_variables() {
	awk 'BEGIN {
		for (name in ENVIRON) {
			value = ENVIRON[name]
			if (name !~ /^[A-Za-z_][A-Za-z0-9_]*$/ ||
				name ~ /^(USER|LOGNAME|SUDO_[A-Za-z0-9_]*)$/ ||
				name ~ /^(LD_|_RLD)/ ||
				name ~ /^(IFS|CDPATH|LOCALDOMAIN|RES_OPTIONS|HOSTALIASES)$/ ||
				name ~ /^(NLSPATH|PATH_LOCALE|TERMINFO|TERMINFO_DIRS)$/ ||
				name ~ /^(TERMPATH|TERMCAP|ENV|BASH_ENV|PS4|GLOBIGNORE)$/ ||
				name ~ /^(BASHOPTS|SHELLOPTS|JAVA_TOOL_OPTIONS|FPATH)$/ ||
				name ~ /^(PERLIO_DEBUG|PERLLIB|PERL5LIB|PERL5OPT|PERL5DB)$/ ||
				name ~ /^(NULLCMD|READNULLCMD|ZDOTDIR|TMPPREFIX|RUBYLIB)$/ ||
				name ~ /^(RUBYOPT|PYTHONHOME|PYTHONPATH|PYTHONINSPECT)$/ ||
				name ~ /^(PYTHONUSERBASE)$/ ||
				value ~ /^\(\)/ ||
				(name ~ /^(COLORTERM|LANG|LANGUAGE|LINGUAS|TERM|LC_.*)$/ &&
					value ~ /[\/%]/) ||
				(name == "TZ" && (value ~ /\.\./ || (value ~ /^:?\// &&
					value !~ /^:?\/usr\/share\/zoneinfo\//))))
				continue
			names = names separator name
			separator = ","
		}
		print names
	}'
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
XDG_STATE_HOME=${XDG_STATE_HOME:-"$user_home/.local/state"}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"$user_home/.cache/run"}
XDG_BIN_HOME=${XDG_BIN_HOME:-"$user_home/.local/bin"}

# Environmental config

script_location=$(
	cd "${0%\/*}" || exit
	pwd
)
# if it has been installed
if [ -L "$script_location/pont" ]; then
	script_link_location=$(readlink "$script_location/pont")
	if ! [ "${script_link_location#\/}" = "$script_link_location" ]; then
		# absolute link
		script_location="$script_link_location"
	else
		# relative link
		script_location="$script_location/$script_link_location"
	fi
	script_location=${script_location%\/*} # cut filename
fi


## This where the packages will be stowed to. Can also be set with -t
PONT_TARGET=${PONT_TARGET:-"$user_home"}
## By default, assume this script is two levels in the dotfiles folder
DOTFILES_HOME=${DOTFILES_HOME:-"$script_location/../.."}
DOTFILES_HOME=$(cd "$DOTFILES_HOME" 2>/dev/null && pwd) || {
	echo "DOTFILES_HOME is not accessible: $DOTFILES_HOME" >&2; exit 1
}
# TODO: Support multiple folders $IFS separated, quote them
PONT_MODULES_HOME=${PONT_MODULES_HOME:-"$DOTFILES_HOME/modules"}
PONT_PRESETS_HOME=${PONT_PRESETS_HOME:-"$DOTFILES_HOME/presets"}
PONT_TEMPLATE_HOME=${PONT_TEMPLATE_HOME:-"$DOTFILES_HOME/template"}

# Config
PONT_LOG_LEVEL=${PONT_LOG_LEVEL:-1}
PONT_CONFIG_FLAG=${PONT_CONFIG_FLAG:-0}
PONT_DRY_FLAG=${PONT_DRY_FLAG:-0}
PONT_FORCE_FLAG=${PONT_FORCE_FLAG:-0}
PONT_NO_BASE_FLAG=${PONT_NO_BASE_FLAG:-0}
PONT_ROOT_FLAG=${PONT_ROOT_FLAG:-1}
PONT_PACKAGE_MANAGER_SCRIPTS_FLAG=${PONT_PACKAGE_MANAGER_SCRIPTS_FLAG:-}
PONT_PACKAGE_MANAGERS=${PONT_PACKAGE_MANAGERS:-"pacman aura paru yay apt \
apt-get xbps-install emerge brew pkg yum dnf zypper choco winget scoop"}
PONT_SCRIPTS_ENABLED=${PONT_SCRIPTS_ENABLED:-1}
PONT_MAKE_ENABLED=${PONT_MAKE_ENABLED:-1}
PONT_PRESET_EXTENSION=${PONT_PRESET_EXTENSION:-".preset"}
PONT_HASHFILE_NAME=${PONT_HASHFILE_NAME:-".tarhash"}
PONT_HASH_HOME=${PONT_HASH_HOME:-}
PONT_DEPRECATIONFILE_NAME=${PONT_DEPRECATIONFILE_NAME:-".deprecated"}
PONT_DEPENDENCIESFILE_NAME=${PONT_DEPENDENCIESFILE_NAME:-".dependencies"}
PONT_CONDITIONFILE_NAME=${PONT_CONDITIONFILE_NAME:-".condition"}
PONT_CLASHFILE_NAME=${PONT_CLASHFILE_NAME:-".clash"}
PONT_TAGSFILE_NAME=${PONT_TAGSFILE_NAME:-".tags"}
PONT_DEFAULT_EXPANSION_ACTION=${PONT_DEFAULT_EXPANSION_ACTION:-"action_expand_none"}
PONT_CLEAN_SYMLINKS=${PONT_CLEAN_SYMLINKS:-0}
PONT_FIX_PERMISSIONS=${PONT_FIX_PERMISSIONS:-0}

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
xbps=$(if is_installed xbps-install; then echo 1; fi)
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
alarm=$(if [ "$distribution" = 'Arch Linux ARM' ]; then echo 1; fi)
export alarm
archx86=$(if [ "$distribution" = 'Arch Linux' ]; then echo 1; fi)
export archx86
arch=$(if [ "$alarm" ] || [ "$archx86" ]; then echo 1; fi)
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

case $PONT_HASH_HOME in
'' | /*) ;;
*)
	echo "PONT_HASH_HOME has to be an absolute path: $PONT_HASH_HOME" >&2
	exit 1
	;;
esac

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

# A module name is a direct child folder of PONT_MODULES_HOME
is_module_name() {
	case $1 in
	'' | */* | *\\* | . | ..) return 1 ;;
	esac
	[ -d "$PONT_MODULES_HOME/$1" ]
}

module_exists() {
	[ ! "$all_modules" ] && get_all_modules
	echo "$all_modules" | grep -qxF -- "$1"
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
	if [ "$PONT_HASH_HOME" ]; then
		[ ! "$all_modules" ] && get_all_modules
		all_installed_modules=$(find "$PONT_HASH_HOME" -maxdepth 1 \
			-mindepth 1 -type f -name "*$PONT_HASHFILE_NAME" -size +0c \
			2>/dev/null | sed 's|.*/||' | while IFS= read -r _hashfile; do
				_module=${_hashfile%"$PONT_HASHFILE_NAME"}
				module_exists "$_module" && echo "$_module"
			done | sort)
	else
		all_installed_modules=$(find "$PONT_MODULES_HOME" -maxdepth 2 \
			-mindepth 2 -type f -name "$PONT_HASHFILE_NAME" -size +0c | \
			sed -E 's_^.*/([^/]*)/[^/]*$_\1_g' | sort)
	fi
}

echo_all_outdated_modules() {
	[ ! "$all_modules" ] && get_all_modules
	for mod in $all_modules; do
		if [ -e "$(hashfile_of "$mod")" ]; then
			fresh_hash="$(do_hash "$mod")"
			old_hash="$(cat "$(hashfile_of "$mod")")"
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
		sed -E 's_^.*/([^/]*)/[^/]*$_\1_g' | sort)
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
# 	while [ "$1" ]; do
# 		execution_queue=$(echo "$execution_queue" | grep -v "$1")
# 		shift
# 	done
# }

enqueue() {
	log_trace "Enqueuing $*"
	while [ "$1" ]; do
		if [ "$execution_queue" ]; then
			execution_queue="${execution_queue}
${1}"
		else
			execution_queue="${1}"
		fi
		shift
	done
}

# Unused, left here for reference
# enqueue_front() {
# 	log_trace "Enqueuing to the front $*"
# 	while [ "$1" ]; do
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
	return 0
}

log_info() {
	# Visible at and under log level 1
	[ "${PONT_LOG_LEVEL:-1}" -le 1 ] && \
		echo "${C_BLUE}[  Info   ]: $*${C_RESET}" >&2
	return 0
}

log_warning() {
	# Visible at and under log level 2
	[ "${PONT_LOG_LEVEL:-1}" -le 2 ] && \
		echo "${C_YELLOW}[ Warning ]: $*${C_RESET}" >&2
	return 0
}

log_success() {
	# Visible at and under log level 2, same as warning but green
	[ "${PONT_LOG_LEVEL:-1}" -le 2 ] && \
		echo "${C_GREEN}[ Success ]: $*${C_RESET}" >&2
	return 0
}

log_error() {
	# Visible at and under log level 3
	[ "${PONT_LOG_LEVEL:-1}" -le 3 ] && \
		echo "${C_RED}[  Error  ]: $*${C_RESET}" >&2
	return 0
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
                                 feature, but if it was turned on by
                                 the environment it turns it off.)
-X, --toggle-fix-permissions  -- Adds user execute permissions to all module
                                 scripts before running them, except in
                                 subfolders with their own .git, such as
                                 submodules and nested clones.
-p, --pull-dotfiles           -- Perform git pull on the dotfiles home folder
-u, --update                  -- Run all scripts starting with u in the
                                 selected modules.
-x, --execute, --install      -- Run init scripts, stow configs, then run
                                 scripts starting with a number and the
                                 Makefile in all the selected modules.
-r, --remove                  -- Unstows every stow package in the selected
                                 modules. If this flag is added twice it will
                                 also run all scripts starting with r in the
                                 selected modules.
-n, --expand-none             -- Expands only the abstract entries in the
                                 selection. No dependencies are resolved.
-e, --expand-selected         -- Expands the original selection (the
                                 argument list) down to its dependencies
                                 recursively. Use this for regular
                                 installations.
-a, --expand-all              -- Expands every module regardless of the
                                 current selection.
-i, --expand-installed        -- Expands every installed module regardless
                                 of the current selection. Useful for batch
                                 running update and backup scripts.
-o, --expand-outdated         -- Expands every installed module regardless
                                 of the current selection that's saved hash
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
                                 Also skips the scripts that require a package
                                 manager and counts them as done, unless
                                 --package-manager-scripts is set.
--package-manager-scripts     -- Enables scripts that require a package
                                 manager. Without this flag or the next one,
                                 they follow --root and --skip-root.
--skip-package-manager-scripts -- Skips scripts that require a package
                                  manager in PONT_PACKAGE_MANAGERS, and counts
                                  them as done, so the fallbacks of their
                                  install group do not run.
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
	echo "pont version: 0.9.0"
}

clean_symlinks() {
	# recursively removes every broken symlink in a directory
	# ! TODO: skip protected files, on mac it tries to delete and fail many
	# ! extended file permission bits are used
	find "${1-$PWD}" -type l -exec \
		sh -c 'for x; do [ -e "$x" ] || rm "$x"; done' _ {} + 2>/dev/null
}

clean_package_symlinks() {
	# $1: package directory
	# $2: target directory
	# removes broken symlinks where the package links, skips linked directories
	[ -d "$2" ] && [ ! -L "$2" ] || return 0
	for _cps_entry in "$1"/* "$1"/.[!.]* "$1"/..?*; do
		[ -e "$_cps_entry" ] || [ -L "$_cps_entry" ] || continue
		_cps_target="$2/${_cps_entry##*/}"
		if [ -L "$_cps_target" ] && [ ! -e "$_cps_target" ]; then
			rm "$_cps_target"
		elif [ -d "$_cps_entry" ]; then
			clean_package_symlinks "$_cps_entry" "$_cps_target"
		fi
	done
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
	_ale_pm=${PONT_PACKAGE_MANAGER_SCRIPTS_FLAG:-${PONT_ROOT_FLAG:-1}}
	echo "PONT_DRY_FLAG=${PONT_DRY_FLAG:-0}" \
		"PONT_FORCE_FLAG=${PONT_FORCE_FLAG:-0}" \
		"PONT_ROOT_FLAG=${PONT_ROOT_FLAG:-1}" \
		"PONT_PACKAGE_MANAGER_SCRIPTS_FLAG=$_ale_pm" \
		"PONT_PACKAGE_MANAGERS=$PONT_PACKAGE_MANAGERS" \
		"PONT_CONFIG_FLAG=${PONT_CONFIG_FLAG:-0}" \
		"PONT_PRESET_EXTENSION=$PONT_PRESET_EXTENSION" \
		"PONT_HASHFILE_NAME=$PONT_HASHFILE_NAME" \
		"PONT_HASH_HOME=$PONT_HASH_HOME" \
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
		"archx86=$archx86" \
		"alarm=$alarm" \
		"arch=$arch" \
		"gentoo=$gentoo" \
		"void=$void" \
		"debian=$debian" \
		"ubuntu=$ubuntu" \
		"fedora=$fedora"
}

## Argument handling

expand_single_args() {
	var="${1#-}" # cut off first, and only dash
	while [ "$var" ]; do
		next="${var#?}"
		first_char="${var%"$next"}"
		# printf: echo takes -n (in bash also -e and -E) as an option
		printf '%s\n' "-$first_char"
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
	set -f # only called in a subshell
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
				echo "$1 is missing its parameter!" >&2
				exit 1
			fi
		fi

		printf "%s\n" "$1"
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
	while [ $# -gt 0 ]; do
		case $1 in
			-h | -\? | --help) show_help ;;
			-V | --version) show_version; exit 0 ;;
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
			--package-manager-scripts)
				PONT_PACKAGE_MANAGER_SCRIPTS_FLAG=1 ;;
			--skip-package-manager-scripts)
				PONT_PACKAGE_MANAGER_SCRIPTS_FLAG=0 ;;
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
				log_trace "yank_target $yank_target"
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
				rename_module "$2" "$3"
				exit 0
				;;
			--)	;;
			-?*) log_error "Unknown option (ignored): $1";;
			*) # The rest are selected modules
				# TODO: Pre validate them
				if [ "$1" ]; then
					if [ "$entries_selected" ]; then
						entries_selected="$entries_selected
$1"
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

has_tag() {
	# Returns every dotmodule that contains any of the tags
	# shellcheck disable=SC2016
	grep -lRxEm 1 -- "$1 ?#?.*" \
		"$PONT_MODULES_HOME"/*/"$PONT_TAGSFILE_NAME" |
		sed -E 's_^.*/([^/]*)/[^/]*$_\1_g'
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
	echo "$1" | cut -d '?' -f 1 | cut -d '#' -f 1 | sed 's/[[:space:]]*$//'
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
			git submodule update --init
		)
	else
		log_error "DOTFILES_HOME ($DOTFILES_HOME) is not a git folder"
	fi
}

# Prints the condition segment of a script name
get_script_condition() {
	# at least 4 section long, so there is a condition
	[ "$(echo "$1" | cut -d '.' -f 4)" ] && echo "$1" | cut -d '.' -f 3
}

script_requires_package_manager() {
	_srpm_condition=$(get_script_condition "$1")
	[ "$_srpm_condition" ] || return 1
	case " $(echo "$PONT_PACKAGE_MANAGERS" | tr '\n' ' ') " in
	*" $_srpm_condition "*) return 0 ;;
	esac
	return 1
}

package_manager_scripts_enabled() {
	[ "${PONT_PACKAGE_MANAGER_SCRIPTS_FLAG:-${PONT_ROOT_FLAG:-1}}" != 0 ]
}

script_condition_file_suffix() {
	printf '.%s' "${PONT_CONDITIONFILE_NAME#.}"
}

without_script_condition_files() {
	_wscf_suffix=$(script_condition_file_suffix)
	while IFS= read -r _wscf_name; do
		case "$_wscf_name" in
		*?"$_wscf_suffix") ;;
		*) printf '%s\n' "$_wscf_name" ;;
		esac
	done
}

is_script_file_name() {
	case "$1" in
	restore*) return 1 ;;
	[0-9eiur]*.*.*) return 0 ;;
	esac
	return 1
}

check_script_condition_file() {
	# 1: module name
	# 2: script name
	# Outputs: script_condition_file_status (0: run, 1: skip, other: fail)
	script_condition_file_status=0
	_cscf_file="$PONT_MODULES_HOME/$1/$2$(script_condition_file_suffix)"
	[ -e "$_cscf_file" ] || return 0
	log_trace "Condition file: ${_cscf_file##*/}"
	# shellcheck disable=SC1090
	(unset IFS; set --; . "$_cscf_file")
	script_condition_file_status=$?
	[ "$script_condition_file_status" = 0 ]
}

warn_unused_script_condition_files() {
	_wuscf_suffix=$(script_condition_file_suffix)
	find "$PONT_MODULES_HOME/$1/" -mindepth 1 -maxdepth 1 -type f \
		-name "?*$_wuscf_suffix" 2>/dev/null |
		while IFS= read -r _wuscf_file; do
			_wuscf_script="${_wuscf_file%"$_wuscf_suffix"}"
			if ! [ -e "$_wuscf_script" ] ||
				! is_script_file_name "${_wuscf_script##*/}"; then
				log_warning "No script for condition file $_wuscf_file"
			fi
		done
}

hashfile_of() {
	if [ "$PONT_HASH_HOME" ]; then
		echo "$PONT_HASH_HOME/$1$PONT_HASHFILE_NAME"
	else
		echo "$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME"
	fi
}

execute_scripts_for_module() {
	# 1: module name
	# 2: scripts to run
	# 3: sourcing setting, if set, user privileged scripts will be sourced
	# Outputs: group_result (sum of exit codes), successful_scripts (count)
	_esm_saved_dir="$PWD"
	cd "$PONT_MODULES_HOME/$1" || { log_error "Cannot cd to module $1"; return 1; }
	group_result=0
	successful_scripts=0
	for script in $2; do
		result=0
		if [ "${PONT_DRY_FLAG:-0}" = 0 ] && \
			[ "${PONT_SCRIPTS_ENABLED:-1}" = 1 ]; then
			log_trace "Running $script..."

			privilege='user'
			[ "$(echo "$script" | grep -o '\.' | wc -w)" -gt 1 ] && \
				privilege=$(echo "$script" | cut -d '.' -f 2 | sed 's/-.*//')
			case "$privilege" in
			root | sudo) root_script=1 ;;
			*) root_script= ;;
			esac

			if ! package_manager_scripts_enabled &&
				script_requires_package_manager "$script"; then
				log_info "Skipping $script because scripts that require" \
					"a package manager are disabled"
			elif [ "$root_script" ] && [ "${PONT_ROOT_FLAG:-1}" != 1 ]; then
				log_info "Skipping $script because root execution" \
					"is disabled"
			elif ! check_script_condition_file "$1" "$script"; then
				if [ "$script_condition_file_status" = 1 ]; then
					log_info "Skipping $script, condition not met"
				else
					log_error "Condition of $script failed: status \
$script_condition_file_status"
					false
				fi
			elif [ "$root_script" ]; then
				(
					sudo_with_environment "$PONT_MODULES_HOME/$1/$script"
				)
			else
				if [ "$SUDO_USER" ]; then
					(
						sudo_with_environment -u "$SUDO_USER" \
							"$PONT_MODULES_HOME/$1/$script"
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
	cd "$_esm_saved_dir" || true
}

do_expand_entries() {
	while [ "$1" ]; do
		# Extracting condition, if there is
		condition="$(get_condition "$1")"
		# TODO: .condition files and $HEADLESS variable !!!
		log_trace "Trying to expand $(get_entry "$1")..."

		[ "$condition" ] && log_trace "...with condition $condition..."

		if ! eval "$condition"; then
			log_info "Condition ($condition) for $1 did not met, skipping"
			shift
			continue
		fi

		# Without its condition, so that each module, preset and tag
		# resolves once, whatever condition its entries have
		_dee_entry=$(get_entry "$1")
		log_trace "Already resolved entries are: $resolved"
		if ! printf '%s\n' "$resolved" | grep -qxF -- "$_dee_entry"; then
			if [ -z "$resolved" ]; then
				resolved="$_dee_entry"
			else
				resolved="$resolved
$_dee_entry"
			fi
			case "$1" in
			+*) # presets
				# printed for a yank action, expand_entries separates them
				get_entry "$1"
				call_with_lines do_expand_entries \
					"$(in_preset "$(get_entry "$1" | cut -c2-)")"
				;;
			:*) # tags
				call_with_lines do_expand_entries \
					"$(has_tag "$(get_entry "$1" | cut -c2-)")"
				;;
			*) # modules
				if [ "${expand_abstract_only:-0}" = 0 ]; then
					call_with_lines do_expand_entries \
						"$(get_dependencies "$(get_entry "$1")")"
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

# Sets final_module_list and expanded_presets. do_expand_entries runs in a
# subshell, so it prints both, presets with their + prefix.
expand_entries() {
	_ee_lines=$(do_expand_entries "$@")
	final_module_list=$(printf '%s\n' "$_ee_lines" | grep -v '^+')
	expanded_presets=$(printf '%s\n' "$_ee_lines" | grep '^+')
}

expand_abstract_entries() {
	expand_abstract_only=1
	expand_entries "$@"
	expand_abstract_only=
}

# Calls $1 with each line of $2 as one argument, without globbing the lines
call_with_lines() {
	_cwl_command=$1
	case $- in *f*) _cwl_noglob=1 ;; *) _cwl_noglob= ;; esac
	set -f
	_cwl_ifs=$IFS
	IFS='
'
	# shellcheck disable=SC2086 # intentional newline split, globbing off
	set -- $2
	IFS=$_cwl_ifs
	[ "$_cwl_noglob" ] || set +f
	"$_cwl_command" "$@"
}

init_modules() {
	log_info "Initializing modules $*"
	while [ "$1" ]; do
		init_scripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
			-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' \
			| grep '^i.*\..*\..*$' | without_script_condition_files | sort)
		execute_scripts_for_module "$1" "$init_scripts_in_module" "1"
		shift
	done
}

source_modules_envs() {
	log_info "Sourcing modules envs $*"
	while [ "$1" ]; do
		env_scripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
			-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' \
			| grep '^e.*\..*\..*$' | without_script_condition_files | sort)
		log_trace "Environmental scripts in $1 are $env_scripts_in_module"
		execute_scripts_for_module "$1" "$env_scripts_in_module" "1"
		shift
	done
}

update_modules() {
	log_info "Updating modules $*"
	while [ "$1" ]; do
		if ! is_module_name "$1"; then
			log_error "Module $1 not found. Skipping"
			shift
			continue
		fi
		if ! check_module_condition "$1"; then
			log_info "Condition on $1 failed. Skipping. $condition"
			shift
			continue
		fi

		# Source env
		source_modules_envs "$1"

		update_scripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
			-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' \
			| grep '^u.*\..*\..*$' | without_script_condition_files | sort)
		execute_scripts_for_module "$1" "$update_scripts_in_module"
		shift
	done
}

remove_modules() {
	log_trace "Removing modules $*"
	while [ "$1" ]; do
		if ! is_module_name "$1"; then
			log_error "Module $1 not found. Skipping"
			shift
			continue
		fi
		module_applies=1
		if ! check_module_condition "$1"; then
			# An installed module keeps its links and its hash, so -r removes
			# them without its remove scripts
			if [ ! -e "$(hashfile_of "$1")" ]; then
				log_info "Condition on $1 failed. Skipping. $condition"
				shift
				continue
			fi
			log_info "Condition on $1 failed. No remove scripts. $condition"
			module_applies=
		fi

		# Source env
		source_modules_envs "$1"

		# Only run the remove scripts with -rr, a single r just unstows
		if [ "$remove_count" -ge 2 ] && [ "$module_applies" ]; then
			log_info "Hard remove $1"
			remove_scripts_in_module=$(find "$PONT_MODULES_HOME/$1/" \
				-mindepth 1 -maxdepth 1 -type f | sed 's|.*/||' |
				grep -v '^restore.*$' | grep '^r.*\..*\..*$' |
				without_script_condition_files | sort)
			execute_scripts_for_module "$1" "$remove_scripts_in_module"
		else
			log_info "Soft remove $1"
		fi

		# Stowing is hard disabled on windows
		if [ -z "$windows" ]; then
			unstow_modules "$1"
		fi

		# remove hashfile to mark as uninstalled
		[ -e "$(hashfile_of "$1")" ] && rm "$(hashfile_of "$1")"

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

	if [ "${PONT_DRY_FLAG:-0}" != 1 ]; then
		if [ ! "$2" ]; then
			log_error "Target variable ${3%%.*} of $3 is empty or not exported"
			[ "$stow_mode" = "stow" ] && stow_failed "$3"
			return
		fi
		# Package target symlinks are always cleaned
		clean_package_symlinks "$1/$3" "$2"
		# A failed simulation keeps every link of the package
		if [ "$stow_mode" = "stow" ] && ! check_stow "$1" "$2" "$3"; then
			stow_failed "$3"
			return
		fi
		# Not stow -R, which keeps the unchanged links, so that file watchers
		# see every link change: https://github.com/aspiers/stow/issues/69
		stow_as_user -D -d "$1" -t "$2" "$3"
		if [ "$stow_mode" = "stow" ]; then
			stow_as_user -S -d "$1" -t "$2" "$3" || stow_failed "$3"
		fi
		log_trace "Stowed $1"
	fi
}

stow_as_user() {
	# Under sudo, the links belong to the user who ran sudo
	if [ "$SUDO_USER" ]; then
		sudo_with_environment -u "$SUDO_USER" stow "$@"
	else
		stow "$@"
	fi
}

check_stow() {
	# $1: the packages parent directory
	# $2: target directory
	# $3: package name
	# Simulates the restow. Prints the output of stow only when it fails.
	if ! _cs_output=$(stow_as_user -n -R -d "$1" -t "$2" "$3" 2>&1); then
		printf '%s\n' "$_cs_output" >&2
		return 1
	fi
}

stow_failed() {
	# $1: package name
	# Fails the module like a failed install script, so pont deletes its hash
	log_error "stow failed for package $1"
	total_result=$((${total_result:-0} + 1))
}

stow_package() {
	# receives a stowmode "stow" | "unstow"
	# then a list of directories of packages inside modules
	stow_mode="$1"
	log_trace "Stowing packages $*"
	shift
	while [ "$1" ]; do

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
			"$(package_target "$(basename "$1")")" \
			"$(basename "$1")" \
			"$stow_mode"
		shift
	done

}

package_target() {
	# $1: package name
	# The variable before the first dot names the target. A relative value is
	# under PONT_TARGET. Without a variable, as in .module, the target is
	# PONT_TARGET. An empty or unset variable gives an empty target.
	_pt_variable="${1%%.*}"
	if [ ! "$_pt_variable" ]; then
		printf '%s\n' "$PONT_TARGET"
		return
	fi
	# A child shell reads the variable, so only an exported one counts
	_pt_value=$(/bin/sh -c "printf '%s' \"\$$_pt_variable\"")
	case $_pt_value in
	'' | /*) printf '%s\n' "$_pt_value" ;;
	*) printf '%s\n' "$PONT_TARGET/$_pt_value" ;;
	esac
}

stow_modules() {
	log_trace "Stow modules $*"
	while [ "$1" ]; do
		# shellcheck disable=SC2046
		# TODO: Mixed splitting, find outputs new line splits
		stow_package "stow" $(find "$PONT_MODULES_HOME/$1" \
			-mindepth 1 -maxdepth 1 -type d -iname "*.$1")
		shift
	done
}

unstow_modules() {
	log_trace "Unstow modules $*"
	while [ "$1" ]; do
		# shellcheck disable=SC2046
		stow_package "unstow" $(find "$PONT_MODULES_HOME/$1" \
			-mindepth 1 -maxdepth 1 -type d -iname "*.$1")
		shift
	done
}

make_module() {
	if [ "${PONT_MAKE_ENABLED:-1}" = 1 ] \
		&& [ -e "$PONT_MODULES_HOME/$1/Makefile" ]; then
		if ! is_installed "make"; then
			log_error "Make not available"; return 1
		fi
		cd "$PONT_MODULES_HOME/$1" || return 1
		# Makefiles are always executed using user rights
		if [ "$SUDO_USER" ]; then
			sudo_with_environment -u "$SUDO_USER" make
		else
			make
		fi
	fi
}

powershell_script_filter() {
	if [ "$windows" ]; then
		grep "^.*ps1$"
	else
		grep -v "^.*ps1$"
	fi
}

get_install_scripts_in_module() {
	find "$PONT_MODULES_HOME/$1/" -mindepth 1 -maxdepth 1 \
		-type f 2>/dev/null | sed 's|.*/||' | grep "^[0-9].*\..*\..*$" |
		without_script_condition_files | sort | powershell_script_filter
}

install_module() {
	warn_unused_script_condition_files "$1"
	scripts_in_module=$(get_install_scripts_in_module "$1")
	log_trace "Scripts in module for $1 are:
$scripts_in_module"
	groups_in_module=$(echo "$scripts_in_module" | sed 's/\..*//g' | uniq)
	for group in $groups_in_module; do
		group_scripts=$(echo "$scripts_in_module" | grep "^${group}..*$" )
	 	group_scripts_to_run=
		for script in $group_scripts; do
			if ! package_manager_scripts_enabled &&
				script_requires_package_manager "$script"; then
				# Counted as done when skipped, even without its package
				# manager, so the fallbacks of the group do not run
				group_scripts_to_run="$group_scripts_to_run
$script"
			# at least 4 section long, so there is a condition
			elif [ "$(echo "$script" | cut -d '.' -f 4)" ]; then
				script_condition="$(echo "$script" | cut -d '.' -f 3)"
				if [ "$script_condition" = "fallback" ]; then
					log_trace "fallback script"
					group_scripts_to_run="$group_scripts_to_run
$script"
				elif [ "${script_condition#\$}" = "$script_condition" ]; then
					log_trace "condition $script_condition is a command"
					is_installed "$script_condition" && \
						group_scripts_to_run="$group_scripts_to_run
$script"
				else
					log_trace "condition $script_condition is a variable"
					[ "$(eval "echo $script_condition")" ] && \
						group_scripts_to_run="$group_scripts_to_run
$script"
				fi
			else
				# else it has no condition
				group_scripts_to_run="$group_scripts_to_run
$script"
			fi
		done
		group_scripts_without_fallback=$(echo "$group_scripts_to_run" |
			 grep -v 'fallback')

		log_trace "scripts to execute after conditions
$group_scripts_without_fallback"

		execute_scripts_for_module "$1" "$group_scripts_without_fallback"

		group_fallback_scripts=$(echo "$group_scripts_to_run" |
			 grep 'fallback')
		if [ "$successful_scripts" = 0 ] && [ "$group_fallback_scripts" ]; then
			log_info "Installing group $group for $1 was not successful, \
trying fallbacks:
$group_fallback_scripts"

			execute_scripts_for_module "$1" "$group_fallback_scripts"
		fi

		total_result=$((total_result + group_result))
	done
}

do_hash() {
	tar --exclude="$PONT_MODULES_HOME/$1/$PONT_HASHFILE_NAME" \
		-c "$PONT_MODULES_HOME/$1" 2> /dev/null | "$HASH_COMMAND"
}

do_hash_module() {
	[ "$PONT_HASH_HOME" ] && mkdir -p "$PONT_HASH_HOME"
	do_hash "$1" >"$(hashfile_of "$1")"
}

hash_module() {
	if [ "${PONT_DRY_FLAG:-0}" = 0 ]; then
		log_success "Successfully installed $1"

		if [ "$SUDO_USER" ]; then
			# shellcheck disable=SC2016
			sudo_with_environment -u "$SUDO_USER" \
				sh -c 'mkdir -p "$(dirname "$4")" &&
					tar --exclude="$1/$3" -c "$1" 2>/dev/null | $2 > "$4"' \
				_ "$PONT_MODULES_HOME/$1" "$HASH_COMMAND" "$PONT_HASHFILE_NAME" \
				"$(hashfile_of "$1")"
		else
			do_hash_module "$1"
		fi
	fi
}

check_module_condition() {
	# Leaves the condition in $condition for the log of the caller
	if [ -e "$PONT_MODULES_HOME/$1/$PONT_CONDITIONFILE_NAME" ]; then
		condition="$(sed -e 's/ *#.*$//' -e '/^$/d' \
			"$PONT_MODULES_HOME/$1/$PONT_CONDITIONFILE_NAME")"
		if ! eval "$condition"; then
			return 1
		fi
	fi
	return 0
}

execute_modules() {
	while [ "$1" ]; do
		total_result=0
		old_hash=
		new_hash=
		log_trace "Checking if module exists: $PONT_MODULES_HOME/$1"
		if ! is_module_name "$1"; then
			log_error "Module $1 not found. Skipping"
			shift
			continue
		fi

		if ! check_module_condition "$1"; then
			log_info "Condition on $1 failed. Skipping. $condition"
			shift
			continue
		fi

		log_info "Installing $1"

		# Only calculate the hashes if we going to use it
		if [ "${PONT_FORCE_FLAG:-0}" = 0 ]; then
			old_hash=$(cat "$(hashfile_of "$1")" 2>/dev/null)
			new_hash=$(do_hash "$1")

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
			if [ -z "$(get_install_scripts_in_module "$1")" ];then
				make_module "$1"
			fi

			install_module "$1"

			if [ "$total_result" = 0 ]; then
				# Calculate fresh hash on success
				hash_module "$1"
			else
				log_error "Installation failed $1"
				[ -e "$(hashfile_of "$1")" ] && rm "$(hashfile_of "$1")"
			fi

		else
			log_info "$1 is already installed and no changes are detected"
		fi
		shift
	done
}

## Actions

action_fix_permissions() {
	# Files under another .git, such as a submodule, belong to that repository
	log_info "Fixing permissions in $PONT_MODULES_HOME... "
	find "$PONT_MODULES_HOME" -mindepth 1 -type d -exec test -e '{}/.git' \; \
		-prune -o -type f -regex '.*\.\(sh\|zsh\|bash\|fish\|dash\)' \
		-exec chmod u+x {} +
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
			entries_selected="${base_module}
${entries_selected}"
		done
		IFS=$old_ifs
	fi
	call_with_lines expand_entries "$entries_selected"
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
	call_with_lines expand_abstract_entries "$entries_selected"
	log_info "Final module list is:
$final_module_list"
}

action_list_modules_to_install() {
	log_info "List modules to install:"
	echo "$final_module_list"
}

action_remove_modules() {
	call_with_lines remove_modules "$final_module_list"
}

action_execute_modules() {
	call_with_lines execute_modules "$final_module_list"
}

action_update_modules() {
	call_with_lines update_modules "$final_module_list"
}

do_yank() {
	mkdir -p "$yank_target"
	# Copy all modules
	while [ "$1" ]; do
		log_info "Yanking $PONT_MODULES_HOME/$1 to $yank_target/$1"
		cp -r "$PONT_MODULES_HOME/$1" "$yank_target/$1"
		shift
	done
	# Copy all used presets
	case $- in *f*) _dy_noglob=1 ;; *) _dy_noglob= ;; esac
	set -f
	for preset in $expanded_presets; do
		preset_file_name="$(echo "$preset" | cut -d '+' -f 2-).preset"
		preset_file=$(find "$PONT_PRESETS_HOME" -type f \
			-name "$preset_file_name")
		if [ -z "$preset_file" ]; then
			log_warning "Preset $preset_file_name not found, not yanked"
			continue
		fi
		cp "$preset_file" "$yank_target/$preset_file_name"
	done
	[ "$_dy_noglob" ] || set +f
}

action_yank() {
	call_with_lines do_yank "$final_module_list"
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
# parse_args can only exit its own subshell, so its failure has to be caught
# here, otherwise execution would fall through to the default install action
parsed_args=$(parse_args "$_args_with_params" "$@") || exit 1
call_with_lines interpret_args "$parsed_args"

# if nothing is selected, ask for modules
if [ "${PONT_CONFIG_FLAG:-0}" = 1 ] || [ $# -eq 0 ]; then
	ask_entries # config checked again to avoid double call on ask_entries
fi

# if nothing is in the execution queue, assume expand and execute
[ ! "$execution_queue" ] \
	 && enqueue "action_expand_selected" "action_execute_modules"

log_trace "Execution queue:
$execution_queue"

[ "$PONT_FIX_PERMISSIONS" = 1 ] && action_fix_permissions
# shellcheck disable=SC2086
execute_queue $execution_queue

[ "$PONT_CLEAN_SYMLINKS" = 1 ] && action_clean_symlinks

set +a
