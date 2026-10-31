#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Under sudo, pont runs the root scripts as root. It runs the user scripts and
# stow as the user who ran sudo. Runs only in CI, because it runs pont as root.
if [ ! "$CI" ] || ! sudo -n true 2>/dev/null; then
	echo "Skipped: needs CI and passwordless sudo"
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
identity='echo "$(id -un) $USER $LOGNAME $SUDO_USER"'
# shellcheck disable=SC2016
printf '#!/bin/sh\n%s >"$PONT_TARGET/sudo_user_user"\n' "$identity" \
	>"$module/1.user.sh"
# shellcheck disable=SC2016
printf '#!/bin/sh\n%s >"$PONT_TARGET/sudo_user_root"\n' "$identity" \
	>"$module/2.root.sh"
chmod +x "$module/1.user.sh" "$module/2.root.sh"

owner() {
	# shellcheck disable=SC2012
	ls -ld "$1" | awk '{print $3}'
}

# Without $COVERAGE: kcov would write its results as root. sudo-rs ignores -E.
sudo -n --preserve-env="$test_variables" ./pont.sh -q -fx sudo_user
sync
# SUDO_USER is root in both steps, because pont itself runs as root
[ "$(cat "$PONT_TARGET/sudo_user_user")" = "$user $user $user root" ] || {
	echo "The user script got the wrong identity:"
	cat "$PONT_TARGET/sudo_user_user"
	exit 1
}
[ "$(cat "$PONT_TARGET/sudo_user_root")" = "root root root root" ] || {
	echo "The root script got the wrong identity:"
	cat "$PONT_TARGET/sudo_user_root"
	exit 1
}
[ -L "$PONT_TARGET/sudo_user_file" ] ||
	{ echo "The package is not linked"; exit 1; }
[ "$(owner "$PONT_TARGET/sudo_user_file")" = "$user" ] ||
	{ echo "The link does not belong to $user"; exit 1; }
[ -e "$module/.tarhash" ] || { echo "The module got no hash"; exit 1; }
[ "$(owner "$module/.tarhash")" = "$user" ] ||
	{ echo "The hash does not belong to $user"; exit 1; }
