#!/bin/sh

script_dir=$(dirname "$(readlink -f "$0")")
echo "env set up into $script_dir"

export DOTFILES_HOME="$script_dir/"
export PONT_MODULES_HOME="$script_dir/modules"
export PONT_PRESETS_HOME="$script_dir/presets"
export PONT_TEMPLATE_HOME="$script_dir/template"
export PONT_TARGET="$script_dir/target"
export PONT_BASE_MODULES=

mkdir -p "$PONT_TARGET"

# Constructs a temporary module
make_dummy_module() {
	mkdir -p "${PONT_MODULES_HOME}/${1:-dummy}"
	echo "${2:-test}" > "${PONT_MODULES_HOME}/${1:-dummy}/dummyfile"
}

clear_dummy_module() {
	rm -r "${PONT_MODULES_HOME}/${1:-dummy}"
}
