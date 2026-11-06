#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Before it stows or unstows a package, pont removes a broken link only at the
# target paths that the package has. -C removes every broken link in
# PONT_TARGET.

dangling="$PONT_MODULES_HOME/scoped_clean/.scoped_clean/fold/inner/dangling"
# Modules that this test makes, so that the module list of test 09 stays
fold_module="$PONT_MODULES_HOME/scoped_clean_fold"
unset_module="$PONT_MODULES_HOME/scoped_clean_unset"
trap 'rm -f "$dangling"; rm -rf "$fold_module" "$unset_module"' EXIT
trap 'exit 1' HUP INT TERM
rm -f "$dangling"
rm -rf "$fold_module" "$unset_module"

mkdir -p "$PONT_TARGET/sub/deeper" "$PONT_TARGET/.hidden" \
	"$PONT_TARGET/..dd" "$PONT_TARGET/other" "$PONT_TARGET/linkdir"
# linkdir is a link to a folder in the package. stow enters it when the
# target has a real folder there, so pont cleans there too.
at_package_paths="topfile sub/subfile .hidden/hiddenfile ..dd/ddfile
	linkdir/realfile"
elsewhere="broken_top sub/broken_sub sub/deeper/broken_deeper
	other/broken_other"
for link in $at_package_paths $elsewhere; do
	ln -s "$PONT_TARGET/missing" "$PONT_TARGET/$link"
done
# Package paths that do not exist yet, such as fold, get no rm error
errors=$(./pont.sh -q scoped_clean scoped_clean_link 2>&1 >/dev/null)
$COVERAGE ./pont.sh -q -fx scoped_clean scoped_clean_link

sync
case $errors in
*rm:*) fail "Cleanup printed an rm error: $errors" ;;
esac
for link in $at_package_paths; do
	[ -e "$PONT_TARGET/$link" ] ||
		fail "Broken link $link was not replaced"
done
[ -L "$PONT_TARGET/fold" ] || fail "fold was not linked"
for link in $elsewhere; do
	[ -L "$PONT_TARGET/$link" ] ||
		fail "Broken link $link outside the package was removed"
done

# fold is a link into the package, so a broken link under it is module source
# and must stay
ln -s missing "$dangling"
$COVERAGE ./pont.sh -q -fx scoped_clean
sync
[ -L "$dangling" ] ||
	fail "A broken link in the module source was removed"

# Nor when that link is the target directory of another package
mkdir -p "$fold_module/SCOPED_CLEAN_FOLD.scoped_clean_fold/inner"
: >"$fold_module/SCOPED_CLEAN_FOLD.scoped_clean_fold/inner/dangling"
SCOPED_CLEAN_FOLD="$PONT_TARGET/fold" $COVERAGE ./pont.sh -q scoped_clean_fold
sync
[ "$(readlink "$dangling")" = missing ] ||
	fail "A target directory that is a link was entered"

# A valid link at a package path stays. stow reports it as a conflict.
rm "$PONT_TARGET/topfile"
ln -s "$PONT_TARGET/other" "$PONT_TARGET/topfile"
$COVERAGE ./pont.sh -q -fx scoped_clean
sync
[ "$(readlink "$PONT_TARGET/topfile")" = "$PONT_TARGET/other" ] ||
	fail "A valid link at a package path was removed"

# Unstow also removes a foreign broken link at a package path, which stow -D
# leaves
rm "$PONT_TARGET/topfile"
ln -s "$PONT_TARGET/missing" "$PONT_TARGET/topfile"
$COVERAGE ./pont.sh -q -r scoped_clean
sync
[ ! -L "$PONT_TARGET/topfile" ] || fail "Unstow kept topfile"
for link in $elsewhere; do
	[ -L "$PONT_TARGET/$link" ] ||
		fail "Unstow removed the broken link $link"
done

$COVERAGE ./pont.sh -q -C -fx scoped_clean
sync
for link in $elsewhere; do
	[ ! -L "$PONT_TARGET/$link" ] ||
		fail "-C kept the broken link $link"
done
[ -L "$dangling" ] ||
	fail "-C removed a broken link in the module source"

# With an unset target variable, the cleanup does not start from /. The
# package mirrors PONT_TARGET from /, so a walk from / would reach probe.
mkdir -p "$unset_module/PONT_SCOPED_UNSET.scoped_clean_unset$PONT_TARGET"
: >"$unset_module/PONT_SCOPED_UNSET.scoped_clean_unset$PONT_TARGET/probe"
ln -s "$PONT_TARGET/missing" "$PONT_TARGET/probe"
$COVERAGE ./pont.sh -q scoped_clean_unset
sync
[ -L "$PONT_TARGET/probe" ] ||
	fail "The cleanup started from / for an unset target"
