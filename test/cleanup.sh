#!/bin/sh
# shellcheck disable=SC1091
. ./test/env.sh

echo "Cleaning up target folder: $PONT_TARGET"
rm -rf "${PONT_TARGET:?}"

echo "Cleaning up hashfiles named: ${PONT_HASHFILE_NAME:-.tarhash}"
find test -iname "${PONT_HASHFILE_NAME:-.tarhash}" -exec rm {} \;
