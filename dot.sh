#!/bin/sh
#      _       _
#   __| | ___ | |_
#  / _` |/ _ \| __|
# | (_| | (_) | |_
#  \__,_|\___/ \__|
#
# The dotmodule manager

# TODO: use make on update and remove too use Make targets, check if exits

# TODO: deprecation alternatives prompt, check nvm and fnm

# TODO: Experiment with `sudo -l` to find out you have sudo access or not
# TODO: If not, automatically turn on `skip-root` and print some message

# TODO: Enable line end comments (just strip #.*$ from every line)
# TODO: Uninstall by default unstow, if full uninstall then run the uninstall
# TODO: scripts, and uninstall should also remove the .tarhash file

# TODO: Clash support. Use .clash file, if two modules clash, ask which to use
# TODO: If a clashing module is already installed, abort, ask if interactive,
# TODO: remove other if forced

# TODO: clash feature support tags, see if something from that tag is installed

# TODO: track dangling dependencies. When installing leave a file in the module
# TODO: that will store a snapshot of the dependencies. During uninstall check
# TODO: If there is a dependency somewhere that is not directly installed.
# TODO: (Or maybe dont and leave this to dot2)

# TODO: If the module contains a git submodule. Check it out / update it

# TODO: Experiment with paralell execution (sort dependencies into a tree)
# TODO: Right now every dependency is sorted into a column and executed
# TODO: sequentially. The new executor would treat everything in one column
# TODO: and one indentation as modules that can be executed paralelly
# TODO: then pass everything below as a dependency list to it with one level
# TODO: of indentation removed
# TODO: make a test modules directory with modules with logs and sleeps
# TODO: Also a buffer output is needed to display this
# TODO: It should keep a buffer as high as many modules are currently being
# TODO: installed and then do the logging above it like normal
# TODO: Or have an indented section below each entry with a preview log
# TODO: or both
# TODO: investigate if feasible
# TODO: add flags to disable or enable paralell work
# TODO: add a .lock file with PID into each module just in case and remove after

# TODO: forced clash on every input module. This is useful when you want to
# TODO: have a menu to install something in a category. combine with
# TODO: no-uninstall flags

# TODO: Change the evals into something safer

# TODO: env.user.sh script support. Always read it even if the module in the

# dependency tree is already installed

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# Make all the variables (except IFS) in this script available to the subshells
set -a

is_installed() {
	command -v "$1" 2>/dev/null
}

# Environment
user_home=$(getent passwd "${SUDO_USER-$USER}" | cut -d: -f6)

# Normalize XDG variables according to the spec (Set it only if absent)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$user_home/.config"}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$user_home/.cache"}
XDG_DATA_HOME=${XDG_DATA_HOME:-"$user_home/.local/share"}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"$user_home/.cache/run"}
XDG_BIN_HOME=${XDG_BIN_HOME:-"$user_home/.local/bin"}

# Environmental config
## This where the packages will be stowed to. Can also be set with -t
DOT_TARGET=${DOT_TARGET:-"$user_home"}
DOTFILES_HOME=${DOTFILES_HOME:-"$user_home/.config/dotfiles"}
# TODO: Support multiple folders $IFS separated, quote them
DOT_MODULES_HOME=${DOT_MODULES_HOME:-"$DOTFILES_HOME/modules"}
DOT_PRESETS_HOME=${DOT_PRESETS_HOME:-"$DOTFILES_HOME/presets"}

# Config
DOT_LOG_LEVEL=1
DOT_CONFIG_FLAG=0
DOT_DRY_FLAG=0
DOT_FORCE_FLAG=0
DOT_NO_BASE_FLAG=0
DOT_ROOT_FLAG=1
DOT_SCRIPTS_ENABLED=1
DOT_MAKE_ENABLED=1
DOT_PRESET_EXTENSION=".preset"
DOT_HASHFILE_NAME=".tarhash"
DOT_DEPRECATIONFILE_NAME=".deprecated"
DOT_DEPENDENCIESFILE_NAME=".dependencies"
DOT_CLASHFILE_NAME=".clash"
DOT_TAGSFILE_NAME=".tags"
DOT_DEFAULT_EXPANSION_ACTION="action_expand_none"
DOT_CLEAN_SYMLINKS=0
DOT_FIX_PERMISSIONS=0


## Pre calculated environmental variables for modules
# Package manager
pacman=$(is_installed pacman)
apt=$(is_installed apt)
xbps=$(is_installed xbps)
# Init system
sysctl=$(is_installed sysctl)
systemctl=$(is_installed systemctl)
# TODO: Check if its available, on WSL it's not, even though systemctl is
systemd=$systemctl
# Distribution
# TODO: Only valid on systemd distros
distribution=$(grep "^NAME" /etc/os-release | grep -oh "=.*" | tr -d '="')
# It uses if and not && because when using && a new line would
# return on false evaluation. `If` captures the output of test
arch=$(if [ "$distribution" = 'Arch Linux' ]; then echo 1; fi)
void=$(if [ "$distribution" = 'Void Linux' ]; then echo 1; fi)
debian=$(if [ "$distribution" = 'Debian GNU/Linux' ]; then echo 1; fi)
ubuntu=$(if [ "$distribution" = 'Ubuntu' ]; then echo 1; fi)
fedora=$(if [ "$distribution" = 'Fedora' ]; then echo 1; fi)

# Config file sourcing
# shellcheck disable=SC1090
[ -e "$XDG_CONFIG_HOME/dot/dotrc" ] && . "$XDG_CONFIG_HOME/dot/dotrc"
# shellcheck disable=SC1090
[ -e "$XDG_CONFIG_HOME/dotrc" ] && . "$XDG_CONFIG_HOME/dotrc"
# shellcheck disable=SC1090
[ -e "$user_home/.dotrc" ] && . "$user_home/.dotrc"
# shellcheck disable=SC1091
[ -e "./.dotrc" ] && . "./.dotrc"

# Inner variables that are not allowed to be changed using dotrc
all_modules=
all_presets=
all_installed_modules=
all_outdated_modules=
all_deprecated_modules=
all_tags=
yank_target=
resolved=
entries_selected=
final_module_list=

# Newline separated list of actions. Used to preserve order of flags
execution_queue=

## Internal functions

is_deprecated() {
	[ -e "$DOT_MODULES_HOME/$1/$DOT_DEPRECATIONFILE_NAME" ]
}

module_exists() {
	[ ! "$all_modules" ] && get_all_modules
	echo "$all_modules" | grep -x "$1"
}

get_all_modules() {
	all_modules=$(find "$DOT_MODULES_HOME/" -maxdepth 1 -mindepth 1 \
		-printf "%f\n" | sort)
}

get_all_presets() {
	all_presets=$(find "$DOT_PRESETS_HOME/" -mindepth 1 \
		-name '*.preset' -printf "%f\n" | sed 's/.preset//' | sort)
}

get_all_installed_modules() {
	#shellcheck disable=SC2016
	all_installed_modules=$(grep -lm 1 -- "" \
		"$DOT_MODULES_HOME"/**/$DOT_HASHFILE_NAME | \
		sed -r 's_^.*/([^/]*)/[^/]*$_\1_g' | sort)
}

echo_all_outdated_modules() {
	[ ! "$all_modules" ] && get_all_modules
	for mod in $all_modules; do
		if [ -e "$DOT_MODULES_HOME/$mod/$DOT_HASHFILE_NAME" ]; then
			fresh_hash="$(do_hash "$mod")"
			old_hash="$(cat "$DOT_MODULES_HOME/$mod/$DOT_HASHFILE_NAME")"
			[ "$fresh_hash" != "$old_hash" ] && echo "$mod"
		fi
	done
}

get_all_outdated_modules() {
	all_outdated_modules=$(echo_all_outdated_modules)
}

get_all_deprecated_modules() {
	#shellcheck disable=SC2016
	all_deprecated_modules=$(grep -lm 1 -- "" \
		"$DOT_MODULES_HOME"/**/$DOT_DEPRECATIONFILE_NAME | \
		sed -r 's_^.*/([^/]*)/[^/]*$_\1_g' | sort)
}

get_all_tags() {
	all_tags=$(find "$DOT_MODULES_HOME"/*/ -maxdepth 1 -mindepth 1 \
		-name '.tags' -exec cat {} + | \
		sed -e 's/ *#.*$//' -e '/^$/d' | sort | uniq)
}

dequeue() {
	# remove last or remove the supplied items
	if [ ! "$1" ]; then
		execution_queue=$(echo "$execution_queue" | sed '$ d')
		return
	fi
	while :; do
		if [ "$1" ]; then
			execution_queue=$(echo "$execution_queue" | grep -v "$1")
			shift
		else
			break
		fi
	done
}

enqueue() {
	log_trace "Enqueuing $*"
	while :; do
		if [ "$1" ]; then
			if [ "$execution_queue" ]; then
				execution_queue="${execution_queue}${IFS:-\0}${1}"
			else
				execution_queue="${1}"
			fi
			shift
		else
			break
		fi
	done
}

enqueue_front() {
	log_trace "Enqueuing to the front $*"
	while :; do
		if [ "$1" ]; then
			if [ "$execution_queue" ]; then
				execution_queue="${1}${IFS:-\0}${execution_queue}"
			else
				execution_queue="${1}"
			fi
			shift
		else
			break
		fi
	done
}

# Logging, the default log level is 1 meaning only trace logs are omitted
log_trace() {
	# Visible at and under log level 0
	[ "${DOT_LOG_LEVEL:-1}" -le 0 ] && \
		echo "${C_CYAN}[  Trace  ]: $*${C_RESET}" >&2
}

log_info() {
	# Visible at and under log level 1
	[ "${DOT_LOG_LEVEL:-1}" -le 1 ] && \
		echo "${C_BLUE}[  Info   ]: $*${C_RESET}" >&2
}

log_warning() {
	# Visible at and under log level 2
	[ "${DOT_LOG_LEVEL:-1}" -le 2 ] && \
		echo "${C_YELLOW}[ Warning ]: $*${C_RESET}" >&2
}

log_success() {
	# Visible at and under log level 2, same as warning but green
	[ "${DOT_LOG_LEVEL:-1}" -le 2 ] && \
		echo "${C_GREEN}[ Success ]: $*${C_RESET}" >&2
}

log_error() {
	# Visible at and under log level 3
	[ "${DOT_LOG_LEVEL:-1}" -le 3 ] && \
		echo "${C_RED}[  Error  ]: $*${C_RESET}" >&2
}

show_help() {
	echo "install <modules>"
	exit
}

show_version() {
	echo "Version: 0.2.0" && exit
}

clean_symlinks() {
	# recusively removes every broken symlink in a directory
	# used to clean before installation and after uninstallation
	find "${1-$PWD}" -type l -exec \
		sh -c 'for x; do [ -e "$x" ] || rm "$x"; done' _ {} +
}

scaffold() {
	# TODO scaffold
	# cpt template and dot --scaffold command to create from template
	# Use the remaining inputs as module folders to scaffold using cpt
	# If cpt is not available then try install it with cargo first
	# If no cargo is available then prompt the user to install it
	log_info "Scaffolding module $1 using cpt"
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
	echo "DOT_DRY_FLAG=${DOT_DRY_FLAG:-0}" \
		"DOT_FORCE_FLAG=${DOT_FORCE_FLAG:-0}" \
		"DOT_ROOT_FLAG=${DOT_ROOT_FLAG:-1}" \
		"DOT_CONFIG_FLAG=${DOT_CONFIG_FLAG:-0}" \
		"DOT_PRESET_EXTENSION=$DOT_PRESET_EXTENSION" \
		"DOT_HASHFILE_NAME=$DOT_HASHFILE_NAME" \
		"DOT_DEPENDENCIESFILE_NAME=$DOT_DEPENDENCIESFILE_NAME" \
		"DOT_CLASHFILE_NAME=$DOT_CLASHFILE_NAME" \
		"DOT_TAGSFILE_NAME=$DOT_TAGSFILE_NAME" \
		"DOT_DEFAULT_EXPANSION_ACTION=$DOT_DEFAULT_EXPANSION_ACTION" \
		"pacman=$pacman" \
		"apt=$apt" \
		"xbps=$xbps" \
		"sysctl=$sysctl" \
		"systemctl=$systemctl" \
		"systemd=$systemd" \
		"distribution=$distribution" \
		"arch=$arch" \
		"void=$void" \
		"debian=$debian" \
		"ubuntu=$ubuntu" \
		"fedora=$fedora" && exit
}

action_list_modules_to_execute() {
	# Print the to-be installed modules
	log_info "List modules to execute:"
	echo "$final_module_list"
}

## Argument handling

parse_args() {
	/usr/bin/getopt -u -o "hVlvq\
IADPT\
ELQO\
CX\
uxrneaio\
dbf\
cRt:s:y:Y:\
S\
" -l "help,version,log,log-level,verbose,quiet,\
list-installed,list-modules,list-deprecated,list-presets,list-tags,\
list-environment,list-install,list-queue,list-outdated,\
toggle-clean-symlinks,toggle-fix-permissions,\
update,install,remove,no-expand,expand,all,all-installed,outdated,\
dry,no-base,force,\
config,root,no-root,skip-root,target,cpt,scaffold,yank,yank-expanded\
no-scripts,skip-scripts\
" -- "$@" || exit 1
}

interpret_args() {
	IFS='
'
	while :; do
		case $1 in
			-h | -\? | --help) show_help ;;
			-V | --version) show_version ;;
			-l | --log | --log-level)
				case $2 in
					'trace' | 'TRACE' | '0') DOT_LOG_LEVEL='0' ;;
					'info' | 'INFO' | '1') DOT_LOG_LEVEL='1' ;;
					'warning' | 'WARNING' | '2') DOT_LOG_LEVEL='2' ;;
					'success' | 'SUCCESS') DOT_LOG_LEVEL='2' ;;
					'error' | 'ERROR' | '3') DOT_LOG_LEVEL='3' ;;
					'none' | 'NONE' | '4') DOT_LOG_LEVEL='4' ;;
					*) log_error "Invalid loglevel: $2"; exit 1 ;;
				esac
				shift
				;;
			-v | --verbose)	DOT_LOG_LEVEL=0 ;; # Log level trace
			-q | --quiet) DOT_LOG_LEVEL=3 ;; # Log level error
			-I | --list-installed) action_list_installed_modules; exit 0 ;;
			-A | --list-modules) action_list_modules; exit 0 ;;
			-D | --list-deprecated) action_list_deprecated; exit 0 ;;
			-P | --list-presets) action_list_presets; exit 0 ;;
			-T | --list-tags) action_list_tags; exit 0 ;;
			-E | --list-environment) action_list_environment; exit 0 ;;
			-L | --list-install) action_list_modules_to_install; exit 0 ;;
			-Q | --list-queue) action_list_execution_queue; exit 0 ;;
			-O | --list-outdated) action_list_outdated; exit 0 ;;
			-C | --toggle-clean-symlinks)
				DOT_CLEAN_SYMLINKS=$((1-DOT_CLEAN_SYMLINKS)) ;;
			-X | --toggle-fix-permissions)
				DOT_FIX_PERMISSIONS=$((1-DOT_FIX_PERMISSIONS)) ;;
			-u | --update) enqueue "action_default_no_expansion" \
				"action_update_modules" ;;
			-x | --execute | --install) enqueue \
				"action_default_no_expansion" "action_execute_modules" ;;
			-r | --remove) # behaves differently when called multiple times
				remove_count=$((${remove_count:-0} + 1))
				[ ${remove_count:-0} = 1 ] && \
					enqueue "action_default_no_expansion" \
							"action_remove_modules" ;;
			-n | --no-expand) enqueue "action_expand_none" ;;
			-e | --expand) enqueue "action_expand_selected" ;;
			-a | --all) enqueue "action_expand_all" ;;
			-i | --all-installed) enqueue "action_expand_installed" ;;
			-o | --outdated) enqueue "action_expand_outdated" ;;
			-d | --dry) DOT_DRY_FLAG=1 ;;
			-b | --no-base) DOT_NO_BASE_FLAG=1 ;;
			-f | --force) DOT_FORCE_FLAG=1; enqueue "action_expand_none" ;;
			-c | --config | --custom) DOT_CONFIG_FLAG=1 ;;
			--root) DOT_ROOT_FLAG=1 ;;
			-R | --no-root | --skip-root) DOT_ROOT_FLAG=0 ;;
			-s | --scripts) DOT_SCRIPTS_ENABLED=1 ;;
			-S | --no-scripts | --skip-scripts) DOT_SCRIPTS_ENABLED=0 ;;
			-m | --make) DOT_MAKE_ENABLED=1 ;;
			-M | --no-make | --skip-make) DOT_MAKE_ENABLED=0 ;;
			-t | --target) # package installation target
				if [ -d "$2" ]; then
					DOT_TARGET="$2"
				else
					log_error "Invalid target: $2"; exit 1
				fi
				shift
				;;
			--scaffold) # Ask for everything
				shift
				scaffold "$@"
				exit 0
				;;
			-y | --yank)
				enqueue "action_default_no_expansion" "action_yank"
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
			--)	;;
			-?*) log_error "Unknown option (ignored): $1" b;;
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
	rev | cut -c2- | rev | cut -c2-
}

has_tag() {
	# Returns every dotmodule that contains any of the tags
	# shellcheck disable=SC2016
	grep -lRxEm 1 -- "$1 ?#?.*" \
		"$DOT_MODULES_HOME"/*/"$DOT_TAGSFILE_NAME" |
		sed -r 's_^.*/([^/]*)/[^/]*$_\1_g'
}

in_preset() {
	# returns every entry in a preset
	find "$DOT_PRESETS_HOME" -mindepth 1 -name "$1$DOT_PRESET_EXTENSION" \
		-print0 | xargs -0 sed -e 's/ *#.*$//' -e '/^$/d'
}

get_clashes() {
	if [ -f "$DOT_MODULES_HOME/$1/$DOT_CLASHFILE_NAME" ]; then
		sed -e 's/ *#.*$//' -e '/^$/d' \
			"$DOT_MODULES_HOME/$1/$DOT_CLASHFILE_NAME"
	fi
}

get_dependencies() {
	if [ -f "$DOT_MODULES_HOME/$1/$DOT_DEPENDENCIESFILE_NAME" ]; then
		sed -e 's/ *#.*$//' -e '/^$/d' \
			"$DOT_MODULES_HOME/$1/$DOT_DEPENDENCIESFILE_NAME"
	fi
}

get_entry() {
	echo "$1" | cut -d '?' -f 1 | cut -d '#' -f 1 | sed 's/ $//'
}

get_condition() {
	echo "$1" | cut -d '?' -s -f 2- | cut -d '#' -f 1  | sed 's/^ //'
}

execute_scripts_for_module() {
	# 1: module name
	# 2: scripts to run
	# 3: sourcing setting, if set, user privileged scripts will be sourced
	for script in $2; do
		if [ ${DOT_DRY_FLAG:-0} = 0 ] && \
			[ ${DOT_SCRIPTS_ENABLED:-1} = 1 ]; then
			log_trace "Running $script..."
			privilige=$(echo "$script" | cut -d '.' -f 2 | sed 's/-.*//')

			if [ "$privilige" = "root" ] ||
				[ "$privilige" = "sudo" ]; then
				if [ "${DOT_ROOT_FLAG:-1}" = 1 ]; then
					(
						sudo "$DOT_MODULES_HOME/$1/$script"
					)
				else
					log_info "Skipping $script because root execution" \
						"is disabled"
				fi
			else
				if [ "$SUDO_USER" ]; then
					(
						sudo -u "$SUDO_USER" "$DOT_MODULES_HOME/$1/$script"
					)
				else
					if [ "$3" ]; then
						# shellcheck disable=SC1090
						. "$DOT_MODULES_HOME/$1/$script"
					else
						(
							"$DOT_MODULES_HOME/$1/$script"
						)
					fi
				fi
			fi
			result=$((result + $?))
		else
			log_trace "Skipping $script..."
		fi
	done
}

do_expand_entries() {
	while :; do
		if [ "$1" ]; then
			# Extracting condition, if there is
			condition="$(get_condition "$1")"

			log_trace "Trying to expand $(get_entry "$1")..."

			[ "$condition" ] && log_trace "...with condition $condition..."

			if ! eval "$condition"; then
				log_info "Condition ($condition) for $1" \
					"did not met, skipping"
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
					do_expand_entries \
						$(get_dependencies "$(get_entry "$1")")
					get_entry "$1"
					;;
				esac
				log_trace "...done resolving $1"
			else
				log_trace "...already resolved $1"
			fi
			shift
		else
			break
		fi
	done
}

expand_entries() {
	final_module_list="$(do_expand_entries "$@")"
}

init_modules() {
	log_info "Initializing modules $*"
	while :; do
		if [ "$1" ]; then
			init_sripts_in_module=$(find "$DOT_MODULES_HOME/$1/" -type f \
				-regex "^.*/init\..*\.sh$" | sed 's|.*/||' | sort)
			execute_scripts_for_module "$1" "$init_sripts_in_module" "1"
			shift
		else
			break
		fi
	done
}

update_modules() {
	log_info "Updating modules $*"
	while :; do
		if [ "$1" ]; then
			update_sripts_in_module=$(find "$DOT_MODULES_HOME/$1/" -type f \
				-regex "^.*/update\..*\.sh$" | sed 's|.*/||' | sort)
			execute_scripts_for_module "$1" "$update_sripts_in_module"
			shift
		else
			break
		fi
	done
}

remove_modules() {
	log_trace "Removing modules $*"
	while :; do
		if [ "$1" ]; then
			# Only run the remove scripts with -rr, a single r just unstows
			if [ "$remove_count" -ge 2 ]; then
				log_info "Hard remove $1"
				remove_sripts_in_module=$(find "$DOT_MODULES_HOME/$1/" \
				-type f -regex "^.*/remove\..*\.sh$" | sed 's|.*/||' | sort)
				execute_scripts_for_module "$1" "$remove_sripts_in_module"
			else
				log_info "Soft remove $1"
			fi

			# unstow
			if [ -e "$DOT_MODULES_HOME/$1/.$1" ]; then
				if [ "$SUDO_USER" ]; then
					sudo -E -u "$SUDO_USER" \
						stow -D -d "$DOT_MODULES_HOME/$1/" \
						-t "$user_home" ".$1"
				else
					stow -D -d "$DOT_MODULES_HOME/$1/" \
						-t "$user_home" ".$1"
				fi
			fi

			# remove hashfile to mark as uninstalled
			[ -e "$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME" ] &&
				rm "$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME"

			shift
		else
			break
		fi
	done
}

do_stow() {
	# $1: the packages parent directory
	# $2: target directory
	# $3: package name

	[ ${DOT_LOG_LEVEL:-1} = 0 ] && echo "Stowing package $3 to $2 from $1"

	if [ ! "$(is_installed stow)" ]; then
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
	if [ ! -d "$2" ]; then
		log_error "target directory does not exist!
	$1
	$2
	$3"
		exit 1
	fi
	if [ ! "$3" ]; then
		log_error "no package name!
	$1
	$2
	$3"
		exit 1
	fi

	if [ ${DOT_DRY_FLAG:-0} != 1 ]; then
		# Module target symlinks are always cleaned
		clean_symlinks "$2"
		if [ "$SUDO_USER" ]; then
			sudo -E -u "$SUDO_USER" stow -D -d "$1" -t "$2" "$3"
			sudo -E -u "$SUDO_USER" stow -S -d "$1" -t "$2" "$3"
		else
			# https://github.com/aspiers/stow/issues/69
			stow -D -d "$1" -t "$2" "$3"
			stow -S -d "$1" -t "$2" "$3"
		fi
	fi
}

stow_package() {
	# recieves a list of directories of packages inside modules
	while :; do
		if [ -d "$1" ]; then
			do_stow "$(echo "$1" | rev | cut -d '/' -f 2- | rev | \
				sed 's|^$|/|')" \
				"$(/bin/sh -c "echo \$$(basename "$1" | rev | \
				    cut -d '.' -f 2- | rev)" | \
					sed -e "s|^\$$|$DOT_TARGET|" \
					-e "s|^[^/]|$DOT_TARGET/\0|")" \
				"$(basename "$1")"
			shift
		else
			break
		fi
	done

}

stow_module() {
	while :; do
		if [ "$1" ]; then
			stow_package "$DOT_MODULES_HOME"/"$1"/*"$1" \
							"$DOT_MODULES_HOME"/"$1"/."$1"
			shift
		else
			break
		fi
	done
}

make_module() {
	if [ ${DOT_MAKE_ENABLED:-1} = 1 ] \
		&& [ -e "$DOT_MODULES_HOME/$1/Makefile" ]; then
		if [ ! "$(is_installed "make")" ]; then
			log_error "Make not available"; exit 1
		fi
		# It's already cd'd in.
		# Makefiles are always executed using user rights
		if [ "$SUDO_USER" ]; then
			sudo -E -u "$SUDO_USER" make
		else
			make
		fi
	fi
}

install_module() {
	sripts_in_module=$(find "$DOT_MODULES_HOME/$1/" -mindepth 1 -maxdepth 1 \
		-type f -regex "^.*/[0-9\]\..*\.sh$" | sed 's|.*/||' | sort)

	[ ${DOT_LOG_LEVEL:-1} = 0 ] && echo "Scripts in module for $1 are:
$sripts_in_module"
	sripts_to_almost_run=
	for script in $sripts_in_module; do
		direct_dependency=$(echo "$script" | cut -d '.' -f 3)
		if [ "$(command -v "$direct_dependency" 2>/dev/null)" ] ||
			[ "$direct_dependency" = "fallback" ]; then
			sripts_to_almost_run="$sripts_to_almost_run${IFS:-\0}$script"
		fi
	done
	sripts_to_run=
	for script in $sripts_to_almost_run; do
		index=$(echo "$script" | cut -d '.' -f 1 |
			sed 's/-.*//')
		direct_dependency=$(echo "$script" | cut -d '.' -f 3)
		# Only keep fallbacks if they are alone in their index
		if [ "$direct_dependency" = "fallback" ]; then
			if [ "$(echo "$sripts_to_almost_run" |
				grep -c "$index.*")" = 1 ]; then
				sripts_to_run="$sripts_to_run${IFS:-\0}$script"
			fi
		else
			sripts_to_run="$sripts_to_run${IFS:-\0}$script"
		fi
	done
	log_trace "Scripts to run for $1 are:
$sripts_to_run"

	# Run the resulting script list
	execute_scripts_for_module "$1" "$sripts_to_run"
}

do_hash() {
	tar --absolute-names \
		--exclude="$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME" \
		-c "$DOT_MODULES_HOME/$1" |
		sha1sum
}

do_hash_module() {
	do_hash "$1" >"$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME"
}

hash_module() {
	if [ ${DOT_DRY_FLAG:-0} = 0 ]; then
		log_success "Successfully installed $1"

		if [ "$SUDO_USER" ]; then
			sudo -E -u "$SUDO_USER" do_hash_module "$1"
		else
			do_hash_module "$1"
		fi
	fi
}

execute_modules() {
	while :; do
		if [ "$1" ]; then
			result=0
			log_trace "Checking if module exists: $DOT_MODULES_HOME/$1"
			if [ ! -d "$DOT_MODULES_HOME/$1" ]; then
				log_error "Module $1 not found. Skipping"
				return 1
			fi

			# cd to dotmodule just in case a dotmodule
			# is not suited for installation outside of it
			cd "$DOT_MODULES_HOME/$1" || return 1

			log_info "Installing $1"

			# Only calculate the hashes if we going to use it
			if [ "${DOT_FORCE_FLAG:-0}" = 0 ]; then
				old_hash=$(cat "$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME" \
					2>/dev/null)
				new_hash=$(tar --absolute-names \
					--exclude="$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME" \
					-c "$DOT_MODULES_HOME/$1" | sha1sum)

				if [ "$old_hash" = "$new_hash" ]; then
					log_trace "${C_GREEN}hash match" \
					"$old_hash" \
					"$new_hash"
				else
					log_trace "${C_RED}hash mismatch" \
					"$old_hash" \
					"$new_hash"
				fi
			fi

			if [ "${DOT_FORCE_FLAG:-0}" = 1 ] \
				|| [ "$old_hash" != "$new_hash" ]; then

				if [ "${DOT_FORCE_FLAG:-0}" != 1 ] && is_deprecated "$1";
					then
					log_warning "$1 is deprecated"
					shift
					continue
				fi

				if [ "${DOT_DRY_FLAG:-0}" = 1 ]; then
					log_trace "Dotmodule $1 would be installed"
				else
					log_trace "Applying dotmodule $1"
				fi

				init_modules "$1"

				stow_module "$1"

				# Make isn't a separate step because there only
				# should be one single install step so that the hashes
				# and the result can be determined in a single step
				make_module "$1"

				install_module "$1"

				if [ "$result" = 0 ]; then
					# Calculate fresh hash on success
					hash_module "$1"
				else
					log_error "Installation failed $1"
					[ -e "$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME" ] &&
						rm "$DOT_MODULES_HOME/$1/$DOT_HASHFILE_NAME"
				fi

			else
				log_info "$1 is already installed and no changes" \
					" are detected"
			fi
			shift
		else
			break
		fi
	done
}

## Actions

action_quit() {
	exit "${1:-0}"
}

action_fix_permissions() {
	# Fix permissions, except in submodules
	log_info "Fixing permissions in $DOTFILES_HOME... "
	submodules=$(
		cd "$DOTFILES_HOME" || exit
		git submodule status | sed -e 's/^ *//' -e 's/ *$//' | rev |
			cut -d ' ' -f 2- | rev | cut -d ' ' -f 2- |
			sed -e 's@^@-not -path "**/@' -e 's@$@/*"@' | tr '\n' ' '
	)

	eval "find $DOT_MODULES_HOME -type f \( $submodules \) \
-regex '.*\.\(sh\|zsh\|bash\|fish\|dash\)' -exec chmod u+x {} \;"
}

action_clean_symlinks() {
	# Remove incorrect symlinks in DOT_TARGET
	clean_symlinks "$DOT_TARGET"
}



action_expand_selected() {
	log_info "Set final module list to every selected module," \
		 " expanding them."
	final_module_list=
	# shellcheck disable=SC2086
	if [ "${DOT_NO_BASE_FLAG:-0}" != 1 ]; then
		if [ "$entries_selected" ]; then
			entries_selected="base${IFS:-\0}$entries_selected"
		else
			entries_selected="base"
		fi
	fi

	expand_entries "base" $entries_selected
	log_info "Final module list is:"
	echo "$final_module_list"
}

action_expand_all() {
	log_info "Set final module list to every module, expanding them."
	final_module_list=
	[ ! "$all_modules" ] && get_all_modules
	# shellcheck disable=SC2086
	expand_entries $all_modules
	log_info "Final module list is:"
	echo "$final_module_list"
}

action_expand_installed() {
	log_info "Set final module list to every installed module," \
			 "expanding them."
	final_module_list=
	[ ! "$all_installed_modules" ] && get_all_installed_modules
	# shellcheck disable=SC2086
	expand_entries $all_installed_modules
	log_info "Final module list is:"
	echo "$final_module_list"
}

action_expand_outdated() {
	log_info "Set final module list to every installed, outdated module," \
			 "expanding them."
	final_module_list=
	[ ! "$all_outdated_modules" ] && get_all_outdated_modules
	# shellcheck disable=SC2086
	expand_entries $all_outdated_modules
	log_info "Final module list is:"
	echo "$final_module_list"
}

action_default_no_expansion() {
	# If no expansion happened at this point, execute the default one
	[ ! "$final_module_list" ] && "$DOT_DEFAULT_EXPANSION_ACTION"
}

action_expand_none() {
	log_info "Set final module list only to the selected modules," \
			 "no expansion."
	final_module_list=$entries_selected
	log_info "Final module list is:"
	echo "$final_module_list"
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
	while :; do
		if [ "$1" ]; then
			log_info "Yanking $DOT_MODULES_HOME/$1 to $yank_target/$1"
			cp -r "$DOT_MODULES_HOME/$1" "$yank_target/$1"
			shift
		else
			break
		fi
	done
}

action_yank() {
	do_yank $final_module_list
}

ask_entries() {
	[ ! "$(is_installed whiptail)" ] && log_error "No whiptail installed" \
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

IFS=' '
# shellcheck disable=SC2046
interpret_args $(parse_args "$@")

# if nothing is selected, ask for modules
[ $DOT_CONFIG_FLAG = 1 ] && ask_entries
[ $DOT_CONFIG_FLAG != 1 ] && [ ! "$entries_selected" ] \
	&& [ ! "$execution_queue" ] \
	&& ask_entries # config checked again to avoid double call on ask_entries

# if nothing is in the execution queue, assume expand and execute
[ ! "$execution_queue" ] \
	 && enqueue "action_expand_selected" "action_execute_modules"

log_trace "Execution queue:
$execution_queue"

[ $DOT_FIX_PERMISSIONS = 1 ] && action_fix_permissions
# shellcheck disable=SC2086
execute_queue $execution_queue

[ $DOT_CLEAN_SYMLINKS = 1 ] && action_clean_symlinks

set +a
