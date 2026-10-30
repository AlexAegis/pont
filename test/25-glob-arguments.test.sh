#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
$COVERAGE ./pont.sh -nL 'pont.*' > /dev/null
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	result=$("$shell" ./pont.sh -nL 'pont.*')
	[ "$result" = "pont.*" ] ||
		{ echo "$shell expanded the argument pont.*: $result"; exit 1; }
done

pont="$(pwd)/pont.sh"
: > "$PONT_TARGET/-V"
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	(cd "$PONT_TARGET" && "$shell" "$pont" '-nL?' x) | grep -q -- '--help' ||
		{ echo "$shell expanded the flag -? in a short flag group"; exit 1; }
done
