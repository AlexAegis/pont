#!/bin/sh

# When installing with pacman always include the --needed and --noconfirm flags
# so dot can work uninterruptedly
pacman -Syu --needed --noconfirm PACKAGE

# When installing with yay you shoud never use sudo.
# This will sudo back to the user of the original sudo command.
# If both pacman and yay needed, it's easier to just make another,
# non-root privileged install script
${SUDO_USER:+sudo -u $SUDO_USER} \
	yay -Syu --needed --noconfirm PACKAGE
