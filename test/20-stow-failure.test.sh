#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# A module whose stow fails gets no hash, so a later run that selects it
# tries it again. A conflict keeps the links of the package. A real folder at
# the path of a package folder is no conflict: stow links the files of the
# package inside it and keeps the other files there. A restow runs stow -D and
# stow -S as two calls, so that file watchers see every link change.

# Modules that this test makes, so that the module list of test 09 stays
# unchanged
module="$PONT_MODULES_HOME/stow_failure"
ok_module="$PONT_MODULES_HOME/stow_failure_ok"
empty_module="$PONT_MODULES_HOME/stow_failure_empty"
hash="$module/.tarhash"
ok_hash="$ok_module/.tarhash"
real_dir="$PONT_TARGET/stow_failure_dir"
trap 'chmod -f u+w "$real_dir"
	rm -rf "$module" "$ok_module" "$empty_module"' EXIT
trap 'exit 1' HUP INT TERM
rm -rf "$module" "$ok_module" "$empty_module"

mkdir -p "$module/.stow_failure" \
	"$ok_module/.stow_failure_ok/stow_failure_dir" "$real_dir" \
	"$empty_module/STOW_FAILURE_EMPTY.stow_failure_empty"
echo package >"$module/.stow_failure/stow_failure_file"
# A script that succeeds must not hide the failed stow
printf '#!/bin/sh\n' >"$module/1.user.sh"
chmod +x "$module/1.user.sh"
echo package >"$ok_module/.stow_failure_ok/stow_failure_dir/ok_file"
echo mine >"$real_dir/untracked"
echo real >"$PONT_TARGET/stow_failure_file"

check_real_dir() {
	if [ ! -d "$real_dir" ] || [ -L "$real_dir" ]; then
		echo "$1: the real folder was replaced"; exit 1
	fi
	[ -L "$real_dir/ok_file" ] || { echo "$1: ok_file is not linked"; exit 1; }
	[ "$(cat "$real_dir/untracked")" = mine ] ||
		{ echo "$1: the other file is gone"; exit 1; }
}

$COVERAGE ./pont.sh -q stow_failure stow_failure_ok
[ ! -e "$hash" ] || { echo "A module whose stow failed got a hash"; exit 1; }
./pont.sh -I | grep -qx stow_failure &&
	{ echo "A module whose stow failed is listed as installed"; exit 1; }
check_real_dir Install
[ -e "$ok_hash" ] ||
	{ echo "The failure of one module failed the next one"; exit 1; }

# A new file shows that the restow ran
echo package >"$ok_module/.stow_failure_ok/stow_failure_dir/ok_file2"
$COVERAGE ./pont.sh -q -fx stow_failure_ok
check_real_dir Restow
[ -L "$real_dir/ok_file2" ] || { echo "The restow did not run"; exit 1; }
[ -e "$ok_hash" ] || { echo "A restow into a real folder failed"; exit 1; }

# A stow on PATH that logs the first argument of each call
stow_bin="$PONT_TARGET/stow_failure_bin"
stow_log="$PONT_TARGET/stow_failure_log"
mkdir -p "$stow_bin"
cat >"$stow_bin/stow" <<STOW
#!/bin/sh
printf '%s\n' "\$1" >>"$stow_log"
exec "$(command -v stow)" "\$@"
STOW
chmod +x "$stow_bin/stow"
PATH="$stow_bin:$PATH" ./pont.sh -q -fx stow_failure_ok
calls=$(tr '\n' ' ' <"$stow_log")
[ "$calls" = '-n -D -S ' ] ||
	{ echo "The restow called stow with: $calls"; exit 1; }

# Without a hash, the next run that selects the module applies it again
rm "$PONT_TARGET/stow_failure_file"
$COVERAGE ./pont.sh -q stow_failure
sync
[ -L "$PONT_TARGET/stow_failure_file" ] ||
	{ echo "The next run did not stow the package"; exit 1; }
[ -e "$hash" ] || { echo "A module that stowed got no hash"; exit 1; }

# A failed stow of an installed module deletes its hash
echo package >"$module/.stow_failure/stow_failure_file2"
echo real >"$PONT_TARGET/stow_failure_file2"
$COVERAGE ./pont.sh -q stow_failure
[ ! -e "$hash" ] ||
	{ echo "An installed module whose stow failed kept its hash"; exit 1; }
[ -L "$PONT_TARGET/stow_failure_file" ] ||
	{ echo "A conflict removed the other links of the package"; exit 1; }

# An unset target variable fails the module
echo package >"$empty_module/STOW_FAILURE_EMPTY.stow_failure_empty/empty_file"
unset STOW_FAILURE_EMPTY
$COVERAGE ./pont.sh -q -fx stow_failure_empty 2>/dev/null
errors=$(./pont.sh -q -fx stow_failure_empty 2>&1 >/dev/null)
case $errors in
*'Target variable STOW_FAILURE_EMPTY of '*) ;;
*) echo "The error does not name the target variable: $errors"; exit 1 ;;
esac
[ ! -e "$empty_module/.tarhash" ] ||
	{ echo "A module with an unset target variable got a hash"; exit 1; }
[ ! -e "$PONT_TARGET/empty_file" ] ||
	{ echo "A package with an unset target variable was linked"; exit 1; }

# A failed unstow does not fail the module when its links are in place. Root
# can write the read-only folder, so the unstow would not fail.
if [ "$(id -u)" != 0 ]; then
	chmod a-w "$real_dir"
	# Without $COVERAGE: kcov in a subshell does not pass the output on
	errors=$(./pont.sh -q -fx stow_failure_ok 2>&1 >/dev/null)
	chmod u+w "$real_dir"
	case $errors in
	*'Could not remove link'*) ;;
	*) echo "The unstow did not fail: $errors"; exit 1 ;;
	esac
	[ -e "$ok_hash" ] || { echo "A failed unstow failed the module"; exit 1; }
fi
