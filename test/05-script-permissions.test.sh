#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test tries to install the `permissions` module.
if ! sudo -n true 2>/dev/null; then
	echo "Skipped: needs passwordless sudo"
	exit 0
fi
$COVERAGE ./pont.sh -q permissions
# Assertions
# The module itself fails when the `user` script runs on root level and when
# the `root` script not.
