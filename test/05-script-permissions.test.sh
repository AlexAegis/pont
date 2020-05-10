#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/.env
# This test tries to install the `permissions` module.
$COVERAGE ./dot.sh permissions
# Assertions
# The module itself fails when the `user` script runs on root level and when
# the `root` script not.
