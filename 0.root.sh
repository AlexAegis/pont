#!/bin/sh

# If this module is installed with --no-root and this script doesn't
# execute, worry not, if you have stow and xdg modules set up, it will be
# available on your path. (Given that XDG_BIN_HOME is defined in the
# xdg module, and on the PATH, and is sourced.)

# when running directly, but from anywhere else than it's location
script_location=$(
	cd "${0%/*}" || exit
	pwd
)

# Using a symlink to make pont available without modifying the PATH

ln -sf "$script_location/pont.sh" "/usr/local/bin/pont"

## Install man page

# install -g 0 -o 0 -m 0644 pont.1 /usr/local/man/man8/
# gzip /usr/local/man/man8/pont.1
