#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# <script>.condition exit status:
# - 0: run
# - 1: skip, count as done
# - other: skip, count as failed

module="$PONT_MODULES_HOME/script_conditions"
failing="$PONT_MODULES_HOME/script_condition_error"
suffix="$PONT_MODULES_HOME/script_condition_suffix"
out="$PONT_TARGET/script_conditions"
stubs="$PONT_TARGET/stubs"
trap 'rm -rf "$module" "$failing" "$suffix"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module" "$failing" "$suffix"
mkdir -p "$module" "$failing" "$suffix" "$out" "$stubs"

make_script() {
	cat >"$1" <<EOF
#!/bin/sh
: >"$out/$2"
EOF
	chmod +x "$1"
}

make_condition_file() {
	cat >"$1" <<EOF
#!/bin/sh
case "\$0" in *.condition) : >"$out/condition-as-script" ;; esac
export PONT_TEST_LEAKED_CONDITION=1
$2
EOF
	chmod +x "$1"
}

cat >"$stubs/sudo" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$out/sudo-calls"
EOF
chmod +x "$stubs/sudo"
PATH="$stubs:$PATH"
export PATH

echo 'export PONT_TEST_SKIPPED_ENV=1' >"$module/e.user.sh"
make_condition_file "$module/e.user.sh.condition" false
echo 'export PONT_TEST_SOURCED_ENV=1' >"$module/e0.user.sh"
make_condition_file "$module/e0.user.sh.condition" true
echo 'export PONT_TEST_SOURCED_INIT=1' >"$module/i.user.sh"
make_condition_file "$module/i.user.sh.condition" true
make_script "$module/1.user.sh" first
make_condition_file "$module/1.user.sh.condition" '[ "$#" = 0 ]'
make_script "$module/2.user.sh" second
make_condition_file "$module/2.user.sh.condition" \
	"[ -e \"$out/first\" ] && [ -e ./2.user.sh ]"
make_script "$module/3.user.sh" third
make_condition_file "$module/3.user.sh.condition" false
make_script "$module/3.user.fallback.sh" fallback
make_script "$module/4.root.sh" root-four
cat >"$module/4.root.sh.condition" <<EOF
: >"$out/root-condition"
false
EOF
make_script "$module/5.root.sh" root-five
# shellcheck disable=SC2016
echo 'echo "condition output in $PONT_TARGET"' >"$module/5.root.sh.condition"
echo true >>"$module/5.root.sh.condition"
make_script "$module/6.user.sh.sh" package-manager
echo ": >\"$out/package-manager-condition\"" >"$module/6.user.sh.sh.condition"
make_script "$module/7.user.sh" default-ifs
# shellcheck disable=SC2016
echo 'words="a b"; set -- $words; [ "$#" = 2 ]' >"$module/7.user.sh.condition"
cat >"$module/8.user.sh" <<EOF
#!/bin/sh
printf '%s %s %s %s\n' "\${PONT_TEST_SKIPPED_ENV:-unset}" \
	"\${PONT_TEST_SOURCED_ENV:-unset}" "\${PONT_TEST_SOURCED_INIT:-unset}" \
	"\${PONT_TEST_LEAKED_CONDITION:-unset}" >"$out/env"
EOF
chmod +x "$module/8.user.sh"
make_script "$module/u.user.sh" update
make_condition_file "$module/u.user.sh.condition" false
make_script "$module/u0.user.sh" update-plain
make_script "$module/r.user.sh" remove
make_condition_file "$module/r.user.sh.condition" false
make_script "$module/r0.user.sh" remove-plain
echo true >"$module/9.user.sh.condition"
echo notes >"$module/notes.txt"
echo true >"$module/notes.txt.condition"

make_script "$failing/1.user.sh" failing-status
echo 'exit 2' >"$failing/1.user.sh.condition"
make_script "$failing/2.user.sh" failing-command
echo pont_test_missing_command >"$failing/2.user.sh.condition"

make_script "$suffix/1.user.second" suffix-like-name
make_script "$suffix/2.user.sh" suffix-condition
echo false >"$suffix/2.user.sh.cond"
echo true >"$suffix/orphan.cond"

$COVERAGE ./pont.sh -q -fx script_conditions
sync
[ -e "$out/first" ] && [ -e "$out/second" ] ||
	{ echo "Script with true condition did not run"; exit 1; }
[ ! -e "$out/condition-as-script" ] ||
	{ echo "Condition file ran as a script"; exit 1; }
[ ! -e "$out/third" ] ||
	{ echo "Script with false condition ran"; exit 1; }
[ ! -e "$out/fallback" ] ||
	{ echo "Fallback ran after a false condition"; exit 1; }
[ -e "$out/root-condition" ] ||
	{ echo "Root script condition did not run"; exit 1; }
grep -q '/5\.root\.sh$' "$out/sudo-calls" ||
	{ echo "Root script with true condition did not call sudo"; exit 1; }
! grep -q '/4\.root\.sh$' "$out/sudo-calls" ||
	{ echo "Root script with false condition called sudo"; exit 1; }
[ -e "$out/default-ifs" ] ||
	{ echo "Condition did not get the default IFS"; exit 1; }
[ "$(cat "$out/env")" = "unset 1 1 unset" ] ||
	{ echo "Wrong env after env and init conditions: $(cat "$out/env")"; exit 1; }
[ -e "$module/.tarhash" ] ||
	{ echo "Module got no hash"; exit 1; }

$COVERAGE ./pont.sh -q -fu script_conditions
sync
[ -e "$out/update-plain" ] ||
	{ echo "Update script without condition did not run"; exit 1; }
[ ! -e "$out/update" ] ||
	{ echo "Update script with false condition ran"; exit 1; }
[ ! -e "$out/condition-as-script" ] ||
	{ echo "Condition file ran as an update script"; exit 1; }

for flags in -fxR -fxS -fxd; do
	rm -f "$out/root-condition" "$out/sudo-calls"
	$COVERAGE ./pont.sh -q "$flags" script_conditions
	sync
	[ ! -e "$out/root-condition" ] ||
		{ echo "Root script condition ran with $flags"; exit 1; }
	[ ! -e "$out/sudo-calls" ] ||
		{ echo "Root script called sudo with $flags"; exit 1; }
done

for flags in --skip-package-manager-scripts -R; do
	rm -f "$out/package-manager-condition"
	PONT_PACKAGE_MANAGERS='sh' \
		$COVERAGE ./pont.sh -q -fx "$flags" script_conditions
	sync
	[ ! -e "$out/package-manager-condition" ] ||
		{ echo "Package manager script condition ran with $flags"; exit 1; }
done

./pont.sh -fx script_conditions >"$out/stdout" 2>"$out/log"
grep -qF "condition output in $PONT_TARGET" "$out/stdout" ||
	{ echo "Condition output missing"; exit 1; }
grep -q 'No script for condition file .*/9\.user\.sh\.condition' "$out/log" ||
	{ echo "No warning for condition file without script"; exit 1; }
grep -q 'No script for condition file .*/notes\.txt\.condition' "$out/log" ||
	{ echo "No warning for condition file of a non-script"; exit 1; }
! grep -q 'condition file .*/5\.root\.sh\.condition' "$out/log" ||
	{ echo "Warning for condition file with a script"; exit 1; }

$COVERAGE ./pont.sh -q -rr script_conditions
sync
[ -e "$out/remove-plain" ] ||
	{ echo "Remove script without condition did not run"; exit 1; }
[ ! -e "$out/remove" ] ||
	{ echo "Remove script with false condition ran"; exit 1; }
[ ! -e "$out/condition-as-script" ] ||
	{ echo "Condition file ran as a remove script"; exit 1; }

$COVERAGE ./pont.sh -q -fx script_condition_error
sync
[ ! -e "$out/failing-status" ] ||
	{ echo "Script ran after condition exit 2"; exit 1; }
[ ! -e "$out/failing-command" ] ||
	{ echo "Script ran after condition with missing command"; exit 1; }
[ ! -e "$failing/.tarhash" ] ||
	{ echo "Module with failed condition got a hash"; exit 1; }

PONT_CONDITIONFILE_NAME=cond $COVERAGE ./pont.sh -q -fx script_condition_suffix
sync
[ -e "$out/suffix-like-name" ] ||
	{ echo "Script named like the suffix did not run"; exit 1; }
[ ! -e "$out/suffix-condition" ] ||
	{ echo "Condition file with custom suffix ignored"; exit 1; }
PONT_CONDITIONFILE_NAME=cond ./pont.sh -fx script_condition_suffix \
	>/dev/null 2>"$out/suffix-log"
grep -q 'No script for condition file .*/orphan\.cond' "$out/suffix-log" ||
	{ echo "No warning for condition file with custom suffix"; exit 1; }
! grep -q '1\.user\.second' "$out/suffix-log" ||
	{ echo "Warning for script named like the suffix"; exit 1; }
