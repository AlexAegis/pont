#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test tries to install the `systemd` module on a systemd system
# being a systemd system is enforced by mocking the is_installed function
# in the .pontrc file
# shellcheck disable=SC2016
echo '
is_installed() {
	if [ "$1" = "systemctl" ]; then
		return 0
	fi
	command -v "$1" 2>/dev/null 1>/dev/null
}
' > .pontrc
result=$($COVERAGE ./pont.sh -q systemd)
rm .pontrc
# Assertions
sync
[ "$result" = "systemd script" ] ||
 	{ echo "Result is empty, systemd script did not run!"; exit 1; }
