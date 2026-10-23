#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Under sudo, pont runs the root scripts as root. It runs the user scripts and
# stow as the user who ran sudo. Runs only in CI, because it runs pont as root.
if [ ! "$CI" ] || ! sudo -n true 2>/dev/null; then
	echo "Skipped: runs only in CI, with a sudo that needs no password"
	exit 0
fi

# Made here, so that the module list of test 09 stays unchanged
module="$PONT_MODULES_HOME/sudo_user"
user=$(id -un)
trap 'rm -rf "$module"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module"

mkdir -p "$module/.sudo_user"
echo package >"$module/.sudo_user/sudo_user_file"
# shellcheck disable=SC2016
printf '#!/bin/sh\nid -un >"$PONT_TARGET/sudo_user_user"\n' >"$module/1.user.sh"
# shellcheck disable=SC2016
printf '#!/bin/sh\nid -un >"$PONT_TARGET/sudo_user_root"\n' >"$module/2.root.sh"
chmod +x "$module/1.user.sh" "$module/2.root.sh"

owner() {
	# shellcheck disable=SC2012
	ls -ld "$1" | awk '{print $3}'
}

# Without $COVERAGE: kcov would write its results as root
sudo -n -E ./pont.sh -q -fx sudo_user
sync
[ "$(cat "$PONT_TARGET/sudo_user_user")" = "$user" ] ||
	{ echo "The user script did not run as $user"; exit 1; }
[ "$(cat "$PONT_TARGET/sudo_user_root")" = root ] ||
	{ echo "The root script did not run as root"; exit 1; }
[ -L "$PONT_TARGET/sudo_user_file" ] ||
	{ echo "The package is not linked"; exit 1; }
[ "$(owner "$PONT_TARGET/sudo_user_file")" = "$user" ] ||
	{ echo "The link does not belong to $user"; exit 1; }
[ -e "$module/.tarhash" ] || { echo "The module got no hash"; exit 1; }
[ "$(owner "$module/.tarhash")" = "$user" ] ||
	{ echo "The hash does not belong to $user"; exit 1; }
