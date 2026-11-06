#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Each option that takes a value refuses an option in the place of its value

for option in -l --log --log-level -t --target -y --yank -Y --yank-expanded \
	--rename; do
	if result=$(./pont.sh "$option" -A 2>&1); then
		fail "$option took -A as its value: $result"
	fi
	[ "$result" = "$option is missing its parameter!" ] ||
		fail "$option -A failed with: $result"
done
