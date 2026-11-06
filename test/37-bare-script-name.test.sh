#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

dots="$PONT_TARGET/dots"
bin="$PONT_TARGET/bin"
other="$PONT_TARGET/other"
decoy="$PONT_TARGET/decoy"
mkdir -p "$dots/modules/pont" "$dots/modules/bare_name_module" "$bin" "$other"
mkdir -p "$decoy/modules/pont" "$decoy/modules/decoy_module"
ln -s "$PWD/pont.sh" "$dots/modules/pont/pont.sh"
ln -s "$PWD/pont.sh" "$decoy/modules/pont/pont.sh"
ln -s ../dots/modules/pont/pont.sh "$bin/pont"
unset DOTFILES_HOME PONT_MODULES_HOME PONT_PRESETS_HOME PONT_TEMPLATE_HOME

expect_modules() {
	sync
	[ "$1" = "bare_name_module
pont" ] ||
		fail "$2 listed: $1"
}

for shell in sh dash bash zsh; do
	command -v "$shell" >/dev/null || continue
	expect_modules "$(cd "$dots/modules/pont" &&
		PATH="$decoy/modules/pont:$PATH" "$shell" pont.sh -A)" "$shell pont.sh"
	expect_modules "$(cd "$dots" && "$shell" modules/pont/pont.sh -A)" \
		"$shell modules/pont/pont.sh"
	expect_modules "$(cd "$other" && "$shell" "$dots/modules/pont/pont.sh" -A)" \
		"$shell <absolute path>"
	expect_modules "$(cd "$other" && "$shell" "$bin/pont" -A)" \
		"$shell <installed link>"
done

expect_modules "$(cd "$other" && PATH="$bin:$PATH" bash pont -A)" \
	"bash pont through PATH"
