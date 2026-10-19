#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# The permission fix makes module scripts executable, except in subfolders
# with their own .git, such as submodules.

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
trap 'exit 1' INT TERM
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=pont GIT_AUTHOR_EMAIL=pont@localhost
export GIT_COMMITTER_NAME=pont GIT_COMMITTER_EMAIL=pont@localhost

git init -q "$scratch/sub"
echo 'echo sub' >"$scratch/sub/sub.sh"
git -C "$scratch/sub" add sub.sh
git -C "$scratch/sub" commit -q -m sub

export DOTFILES_HOME="$scratch/dotfiles"
export PONT_MODULES_HOME="$DOTFILES_HOME/modules"
plain="$PONT_MODULES_HOME/plain/plain.sh"
git init -q "$DOTFILES_HOME"
mkdir -p "$PONT_MODULES_HOME/plain"
echo 'echo plain' >"$plain"
chmod 644 "$plain"

$COVERAGE ./pont.sh -X -L
[ -x "$plain" ] || { echo "Module script was not made executable"; exit 1; }

for sub in sub_a 'sub b'; do
	git -C "$DOTFILES_HOME" -c protocol.file.allow=always \
		submodule add -q "$scratch/sub" "modules/$sub"
	chmod 644 "$PONT_MODULES_HOME/$sub/sub.sh"
done
git init -q "$PONT_MODULES_HOME/plain/clone"
echo 'echo clone' >"$PONT_MODULES_HOME/plain/clone/clone.sh"
chmod 644 "$plain" "$PONT_MODULES_HOME/plain/clone/clone.sh"

$COVERAGE ./pont.sh -X -L
[ -x "$plain" ] ||
	{ echo "Module script next to submodules was not made executable"; exit 1; }
for sub in sub_a 'sub b'; do
	[ ! -x "$PONT_MODULES_HOME/$sub/sub.sh" ] ||
		{ echo "Script in submodule $sub was made executable"; exit 1; }
done
[ ! -x "$PONT_MODULES_HOME/plain/clone/clone.sh" ] ||
	{ echo "Script in a nested repository was made executable"; exit 1; }

git init -q "$PONT_MODULES_HOME"
chmod 644 "$plain"
$COVERAGE ./pont.sh -X -L
[ -x "$plain" ] ||
	{ echo "Script was not made executable when modules has a .git"; exit 1; }
