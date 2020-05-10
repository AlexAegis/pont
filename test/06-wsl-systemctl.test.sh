#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test tries to install the `permissions` module.
# faking wsl
echo "export wsl=1" > .pontrc
result=$($COVERAGE ./pont.sh -q systemd)
rm .pontrc
# Assertions
sync
[ "$result" = "" ] ||
 	{ echo "Result is not empty, systemd script ran on wsl"; exit 1; }
