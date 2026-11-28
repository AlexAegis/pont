#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
module="$PONT_MODULES_HOME/unstow_failure"
hash="$module/.tarhash"
link="$PONT_TARGET/unstow_failure_file"
plain="$PONT_TARGET/unstow_failure_plain"
locked="$PONT_TARGET/unstow_failure_locked"
bin="$PONT_TARGET/unstow_failure_bin"
trap 'chmod 755 "$locked" 2>/dev/null; rm -rf "$module" "$locked" "$bin"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module"

mkdir -p "$module/UNSTOW_FAILURE_TARGET.unstow_failure" \
	"$module/.unstow_failure"
echo package >"$module/UNSTOW_FAILURE_TARGET.unstow_failure/unstow_failure_file"
echo package >"$module/.unstow_failure/unstow_failure_plain"
export UNSTOW_FAILURE_TARGET="$PONT_TARGET"

$COVERAGE ./pont.sh -q unstow_failure
[ -L "$link" ] && [ -L "$plain" ] && [ -e "$hash" ] ||
	fail "The module did not install"

unset UNSTOW_FAILURE_TARGET
chmod 444 "$hash"
$COVERAGE ./pont.sh -q -r unstow_failure 2>/dev/null &&
	fail "pont exited with 0 after a failed unstow"
[ -L "$link" ] || fail "-r removed the link without a target"
[ ! -L "$plain" ] || fail "-r kept the link of the package with a target"
[ -s "$hash" ] || fail "-r removed the hash of a module that keeps its links"
./pont.sh -I | grep -qx unstow_failure ||
	fail "-I does not list the module that keeps its links"
./pont.sh -O | grep -qx unstow_failure ||
	fail "-O does not list the module that lost links"

export UNSTOW_FAILURE_TARGET="$PONT_TARGET"
$COVERAGE ./pont.sh -q unstow_failure
[ -L "$plain" ] || fail "The next install did not stow the module again"
$COVERAGE ./pont.sh -q -r unstow_failure
sync
[ ! -L "$link" ] || fail "The later -r kept the link"
[ ! -e "$hash" ] || fail "The later -r kept the hash"

mkdir -p "$module/.unstow_failure/unstow_failure_locked" "$locked"
echo package >"$module/.unstow_failure/unstow_failure_locked/inner"
$COVERAGE ./pont.sh -q unstow_failure
[ -L "$locked/inner" ] || fail "The module did not install into the folder"
chmod 555 "$locked"
$COVERAGE ./pont.sh -q -r unstow_failure 2>/dev/null &&
	fail "pont exited with 0 after a failed stow -D"
[ -L "$locked/inner" ] || fail "The link in the locked folder is gone"
[ -s "$hash" ] || fail "-r removed the hash after a failed stow -D"

chmod 755 "$locked"
$COVERAGE ./pont.sh -q -fx unstow_failure
full=$(cat "$hash")
mkdir -p "$bin"
cat >"$bin/sudo" <<'EOF'
#!/bin/sh
case "$*" in
	*"unstow failed"*) exit 1 ;;
esac
[ "$1" = --version ] && echo 'Sudo version 1.9' && exit 0
while [ $# -gt 0 ]; do
	case "$1" in
		-u) shift 2 ;;
		-*) shift ;;
		*) break ;;
	esac
done
exec "$@"
EOF
chmod +x "$bin/sudo"
unset UNSTOW_FAILURE_TARGET
PATH="$bin:$PATH" SUDO_USER=$(id -un) \
	$COVERAGE ./pont.sh -q -r unstow_failure 2>/dev/null &&
	fail "pont exited with 0 after a failed unstow under sudo"
[ "$(cat "$hash")" = "$full" ] ||
	fail "A failed write of the mark changed or removed the hash"
