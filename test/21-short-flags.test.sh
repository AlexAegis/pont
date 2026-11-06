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
		fail "The split in $shell dropped -n: $result"
done

if command -v bash >/dev/null; then
	result=$(bash ./pont.sh -neQ | tr '\n' ' ')
	[ "$result" = "action_expand_none action_expand_selected " ] ||
		fail "The split in bash dropped -e: $result"
	bash ./pont.sh -qE | grep -q '^PONT_DRY_FLAG=' ||
		fail "The split in bash dropped -E"
fi
