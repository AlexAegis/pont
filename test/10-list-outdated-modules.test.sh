#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# This test checks if the script can find all outdated modules, modules
# that have been changed since the last installation

make_dummy_module dummy test1
./pont.sh -q dummy
make_dummy_module dummy test2

$COVERAGE ./pont.sh -O
result=$(./pont.sh -O)
clear_dummy_module dummy
# Assertions
sync
[ "$result" = "dummy" ] ||
 	{ echo "Not all outdated modules have been listed!"; exit 1; }
