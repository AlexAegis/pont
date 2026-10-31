#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# When a user runs pont, a root script gets the exported variables minus those
# that sudo -E removes. USER and LOGNAME are root. CI only, because the script
# runs as root.
if [ ! "$CI" ] || ! sudo -n true 2>/dev/null; then
	echo "Skipped: needs CI and passwordless sudo"
	exit 0
fi

# Made here, so that the module list of test 09 stays unchanged
module="$PONT_MODULES_HOME/sudo_environment"
trap 'rm -rf "$module"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module"

mkdir -p "$module"
cat >"$module/1.root.sh" <<'EOF'
#!/bin/sh
env | grep -E '^(USER|LOGNAME|PONT_TEST_[A-Z]*|PYTHONPATH|PERL5LIB|TZ)=' |
	sort >"$PONT_TARGET/sudo_environment"
EOF
chmod +x "$module/1.root.sh"

PONT_TEST_KEPT=kept PYTHONPATH=/python PERL5LIB=/perl \
	PONT_TEST_FUNCTION='() { :; }' TZ=../../etc/passwd \
	$COVERAGE ./pont.sh -q -fx sudo_environment
expected=$(printf '%s\n' LOGNAME=root PONT_TEST_KEPT=kept USER=root)
[ "$(cat "$PONT_TARGET/sudo_environment")" = "$expected" ] || {
	echo "The root script got the wrong environment:"
	cat "$PONT_TARGET/sudo_environment"
	exit 1
}
