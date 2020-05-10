#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This is an example test.
# First every test should set the flag `-e` to error out on any failure
# immediately.
# Then they all should source the test environment, so the script only
# interacts in this folder.

# Then run whatever the test should run

# Then do assertions, and before that, call `sync` so changes are written to
# the disk. If a test fails, the test should exit with 1, and optionally
# print a message

# Assertions
sync
var="1"
[ 1 = "$var" ] ||
	{ echo "Base not linked"; exit 1; }

# This example test always succeeds, you can use it to trigger cleanup
# through `make`
# ```sh
# make test/00-example.test
# ```
