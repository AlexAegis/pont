#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# With PONT_HASH_HOME set, the install hash goes to that folder instead of
# the module folder, so a user can apply modules from a read-only tree.

export PONT_HASH_HOME="$PONT_TARGET/hashes"
make_dummy_module dummy test1
$COVERAGE ./pont.sh -q dummy
module_hash_written=$(if [ -e "$PONT_MODULES_HOME/dummy/.tarhash" ]; then
	echo 1; fi)
installed=$(./pont.sh -I)
make_dummy_module dummy test2
outdated=$(./pont.sh -O)
$COVERAGE ./pont.sh -q -r dummy
clear_dummy_module dummy

sync
[ ! "$module_hash_written" ] ||
	{ echo "Hash was written into the module folder"; exit 1; }
[ "$installed" = "dummy" ] ||
	{ echo "Installed list not correct: $installed"; exit 1; }
[ "$outdated" = "dummy" ] ||
	{ echo "Outdated list not correct: $outdated"; exit 1; }
[ ! -e "$PONT_HASH_HOME/dummy.tarhash" ] ||
	{ echo "Removal left the hash in PONT_HASH_HOME"; exit 1; }

# A second install reads the hash and runs no script
$COVERAGE ./pont.sh -q packages
rm "$PONT_TARGET/packages/plain"
$COVERAGE ./pont.sh -q packages
sync
[ ! -e "$PONT_TARGET/packages/plain" ] ||
	{ echo "Installed module ran again"; exit 1; }

# Files that are not hashes of existing modules are neither listed nor removed
echo hash > "$PONT_HASH_HOME/ghost.tarhash"
echo note > "$PONT_HASH_HOME/notes"
echo kept > "$PONT_TARGET/victim.tarhash"
installed=$(./pont.sh -I)
$COVERAGE ./pont.sh -q -r ../victim
sync
[ "$installed" = "packages" ] ||
	{ echo "Installed list not correct: $installed"; exit 1; }
[ -e "$PONT_TARGET/victim.tarhash" ] ||
	{ echo "Removal deleted a file outside PONT_HASH_HOME"; exit 1; }

# A name that leaves the modules folder is not a module. ../target is the
# folder $PONT_TARGET. Its hash would be $PONT_TARGET/target.tarhash
$COVERAGE ./pont.sh -q -fx ../target
sync
[ ! -e "$PONT_TARGET/target.tarhash" ] ||
	{ echo "Install wrote a hash outside PONT_HASH_HOME"; exit 1; }

# . and .. are not modules, also without PONT_HASH_HOME
echo kept > "$PONT_MODULES_HOME/.tarhash"
echo kept > "$PONT_MODULES_HOME/../.tarhash"
PONT_HASH_HOME= $COVERAGE ./pont.sh -q -r .
PONT_HASH_HOME= $COVERAGE ./pont.sh -q -r ..
sync
[ -e "$PONT_MODULES_HOME/.tarhash" ] ||
	{ echo "Removal of . deleted the hash of the modules folder"; exit 1; }
[ -e "$PONT_MODULES_HOME/../.tarhash" ] ||
	{ echo "Removal of .. deleted a hash above the modules folder"; exit 1; }

# A module folder whose name starts with a dot is still a module
make_dummy_module .dotmod test1
$COVERAGE ./pont.sh -q .dotmod
dotmod_hash=$(if [ -s "$PONT_HASH_HOME/.dotmod.tarhash" ]; then echo 1; fi)
clear_dummy_module .dotmod
[ "$dotmod_hash" ] ||
	{ echo "A dot-prefixed module was not installed"; exit 1; }

if PONT_HASH_HOME="relative/hashes" ./pont.sh -q packages; then
	echo "A relative PONT_HASH_HOME was accepted"; exit 1
fi
if PONT_HASH_HOME="relative/hashes" ./pont.sh -I; then
	echo "A relative PONT_HASH_HOME was accepted by -I"; exit 1
fi
