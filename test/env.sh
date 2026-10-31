#!/bin/sh

script_dir=$(dirname "$(readlink -f "$0")")
echo "env set up into $script_dir"

# Keep the pont settings of the user who runs the tests out of them
for pont_variable in $(env | sed -n 's/^\(PONT_[A-Za-z0-9_]*\)=.*/\1/p' |
	tr '\n' ' '); do
	unset "$pont_variable"
done

export DOTFILES_HOME="$script_dir/"
export PONT_MODULES_HOME="$script_dir/modules"
export PONT_PRESETS_HOME="$script_dir/presets"
export PONT_TEMPLATE_HOME="$script_dir/template"
export PONT_TARGET="$script_dir/target"
export PONT_BASE_MODULES=
# Keep the pontrc in the config folder of the user who runs the tests out of
# them. pont still reads ~/.pontrc and ./.pontrc.
export XDG_CONFIG_HOME="$script_dir/target/config"
# Names of the variables above, for sudo --preserve-env
test_variables=DOTFILES_HOME,PONT_MODULES_HOME,PONT_PRESETS_HOME
test_variables=$test_variables,PONT_TEMPLATE_HOME,PONT_TARGET
test_variables=$test_variables,PONT_BASE_MODULES,XDG_CONFIG_HOME

mkdir -p "$PONT_TARGET"

# Constructs a temporary module
make_dummy_module() {
	mkdir -p "${PONT_MODULES_HOME}/${1:-dummy}"
	echo "${2:-test}" > "${PONT_MODULES_HOME}/${1:-dummy}/dummyfile"
}

clear_dummy_module() {
	rm -r "${PONT_MODULES_HOME}/${1:-dummy}"
}
