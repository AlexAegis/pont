#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# A group of short flags keeps the flags that echo takes as its own: -n in
# every shell, -e and -E in bash
$COVERAGE ./pont.sh -nQ
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	result=$("$shell" ./pont.sh -nQ)
	[ "$result" = "action_expand_none" ] ||
		{ echo "The split in $shell dropped -n: $result"; exit 1; }
done

if command -v bash >/dev/null; then
	result=$(bash ./pont.sh -neQ | tr '\n' ' ')
	[ "$result" = "action_expand_none action_expand_selected " ] ||
		{ echo "The split in bash dropped -e: $result"; exit 1; }
	bash ./pont.sh -qE | grep -q '^PONT_DRY_FLAG=' ||
		{ echo "The split in bash dropped -E"; exit 1; }
fi
