#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh

module="$PONT_MODULES_HOME/name_segments"
out="$PONT_TARGET/name_segments"
trap 'rm -rf "$module" "$out" ./segment_ran ./package_ran ./target_ran' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module" "$out" ./segment_ran ./package_ran ./target_ran
mkdir -p "$module" "$out"

step() {
	# shellcheck disable=SC2016
	printf '#!/bin/sh\nprintf "%%s\\n" "%s" >>"$PONT_TARGET/name_segments/steps"\n' \
		"$2" >"$module/$1"
	chmod +x "$module/$1"
}

# shellcheck disable=SC2016
step '1.user.$pont_test_set.sh' set
# shellcheck disable=SC2016
step '2.user.$pont_test_unset.sh' unset
# shellcheck disable=SC2016
step '3.user.$(touch${IFS}segment_ran).sh' substitution
# shellcheck disable=SC2016
step '4.user.$1x.sh' digit
# shellcheck disable=SC2016
mkdir -p "$module/"'XDG_CONFIG_HOME.$(touch${IFS}package_ran).name_segments'
# shellcheck disable=SC2016
mkdir -p "$module/"'x";touch${IFS}target_ran;".name_segments'
mkdir -p "$module/.name_segments"
echo linked >"$module/.name_segments/name_segments_file"

pont_test_set=1 $COVERAGE ./pont.sh -q -fx name_segments 2>"$out/errors" ||
	true

[ ! -e ./segment_ran ] ||
	fail "The condition segment of a step name ran a command"
[ ! -e ./package_ran ] ||
	fail "The condition segment of a package name ran a command"
[ ! -e ./target_ran ] ||
	fail "The target variable of a package name ran a command"
[ "$(cat "$out/steps")" = set ] ||
	fail "Wrong steps ran: $(cat "$out/steps")"
[ -L "$PONT_TARGET/name_segments_file" ] ||
	fail "The package without a condition is not linked"
grep -q 'segment_ran' "$out/errors" ||
	fail "No message names the step with the substitution:
$(cat "$out/errors")"
