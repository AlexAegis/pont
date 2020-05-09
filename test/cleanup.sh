#!/bin/sh

echo "After all $DOT_HASHFILE_NAME"

# shellcheck disable=SC1091
. test/.env

echo "Cleaning up target folder: $DOT_TARGET"
rm -rf "${DOT_TARGET:?}"

echo "Cleaning up hashfiles named: ${DOT_HASHFILE_NAME:-.tarhash}"
find test -iname "${DOT_HASHFILE_NAME:-.tarhash}" -exec rm {} \;
