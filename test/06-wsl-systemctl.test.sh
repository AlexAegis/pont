#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/.env
# This test tries to install the `permissions` module.
# faking wsl
echo "export wsl=1" > .dotrc
result=$($COVERAGE ./dot.sh -q systemd)
rm .dotrc
# Assertions
sync
[ "$result" = "" ] ||
 	{ echo "Result is not empty, systemd script ran on wsl"; exit 1; }
