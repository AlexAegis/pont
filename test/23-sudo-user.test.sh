#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Under sudo, pont runs the root scripts and their conditions as root. It runs
# the user scripts, their conditions and stow as the user who ran sudo. Runs
# only in CI, because it runs pont as root.
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
printf '#!/bin/sh\n%s >"$PONT_TARGET/sudo_user_user"\n%s\n' "$identity" \
	'printf "%s\n" "$HOME" >"$PONT_TARGET/sudo_user_home"' >"$module/1.user.sh"
# shellcheck disable=SC2016
printf '%s\n' 'echo "$(id -un) $SUDO_USER" >"$PONT_TARGET/sudo_user_module_condition"' \
	>"$module/.condition"
# shellcheck disable=SC2016
printf '%s\n' 'echo "$(id -un) $SUDO_USER" >"$PONT_TARGET/sudo_user_user_condition"' \
	>"$module/1.user.sh.condition"
# shellcheck disable=SC2016
printf '%s\n' 'echo "$(id -un) $SUDO_USER" >"$PONT_TARGET/sudo_user_root_condition"' \
	>"$module/2.root.sh.condition"
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
[ "$(cat "$PONT_TARGET/sudo_user_user")" = "$user $user $user root" ] ||
	fail "The user script got the wrong identity:
$(cat "$PONT_TARGET/sudo_user_user")"
[ "$(cat "$PONT_TARGET/sudo_user_root")" = "root root root root" ] ||
	fail "The root script got the wrong identity:
$(cat "$PONT_TARGET/sudo_user_root")"
user_home=$(getent passwd "$user" | cut -d: -f6)
[ "$(cat "$PONT_TARGET/sudo_user_home")" = "$user_home" ] ||
	fail "The user script got the HOME $(cat "$PONT_TARGET/sudo_user_home")"
for condition in "module $user" "user $user" "root root"; do
	[ "$(cat "$PONT_TARGET/sudo_user_${condition%% *}_condition")" = \
		"${condition#* } $user" ] ||
		fail "The ${condition%% *} condition ran as \
$(cat "$PONT_TARGET/sudo_user_${condition%% *}_condition")"
done
[ -L "$PONT_TARGET/sudo_user_file" ] ||
	fail "The package is not linked"
[ "$(owner "$PONT_TARGET/sudo_user_file")" = "$user" ] ||
	fail "The link does not belong to $user"
[ -e "$module/.tarhash" ] || fail "The module got no hash"
[ "$(owner "$module/.tarhash")" = "$user" ] ||
	fail "The hash does not belong to $user"
