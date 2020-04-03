#!/bin/sh

# when running directly, but from anywhere
script_location=$(
	cd "${0%/*}" || exit
	pwd
)

# when running through `dot`
[ -e "./dot.sh" ] && script_location='.'

# Using a symlink to make dot available without modifying the PATH
ln -sf "$script_location/dot.sh" "/usr/local/bin/dot"

## Install man page

# install -g 0 -o 0 -m 0644 dot.1 /usr/local/man/man8/
# gzip /usr/local/man/man8/dot.1
