#!/bin/sh

script_dir=$(dirname $(readlink -f $0))
echo "env set up into $script_dir"

export DOTFILES_HOME="$script_dir/"
export DOT_MODULES_HOME="$script_dir/modules"
export DOT_PRESETS_HOME="$script_dir/presets"
export DOT_TEMPLATE_HOME="$script_dir/template"
export DOT_TARGET="$script_dir/target"
export DOT_BASE_MODULES=

mkdir -p "$DOT_TARGET"
