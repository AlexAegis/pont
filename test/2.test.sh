#!/bin/sh

pwd
. ./test/.env
echo $DOT_MODULES_HOME
echo "Run tests2"
$COVERAGE ./dot.sh multi
