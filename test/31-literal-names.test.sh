#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Names of modules and presets stay literal: in module lists, where a file
# whose name matches them as a glob does not replace them, and in the patterns
# of find and tar. pont stows and unstows the packages of such a module.

module_name='literal_names[1]'
module="$PONT_MODULES_HOME/$module_name"
base="$PONT_MODULES_HOME/literal_names_base[1]"
presets="$PONT_PRESETS_HOME/literal_names"
lookalike_preset="$presets/literal_names_preset1.preset"
cwd="$PONT_TARGET/literal_names"
yank="$PONT_TARGET/literal_names_yank"
bin="$PONT_TARGET/literal_names_bin"
packages="$PONT_MODULES_HOME/literal_packages[1]"
lookalike_packages="$PONT_MODULES_HOME/literal_packages1"
trap 'rm -rf "$module" "$base" "$presets" "$packages" "$lookalike_packages"' \
	EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module" "$base" "$presets" "$cwd" "$yank" "$bin" \
	"$packages/.literal_packages[1]" "$packages/.literal_packages1" \
	"$lookalike_packages/.literal_packages1"
: >"$packages/.literal_packages[1]/literal_packages_file"
: >"$packages/.literal_packages1/literal_packages_inner_lookalike_file"
: >"$lookalike_packages/.literal_packages1/literal_packages_lookalike_file"
echo test >"$module/dummyfile"
for suffix in '[1]' '*'; do
	printf '%s\n' "$module_name" >"$presets/literal_names_preset$suffix.preset"
done
printf '%s\n' 'literal_names_base[1]' >"$lookalike_preset"
: >"$cwd/literal_names1"
: >"$cwd/literal_names_base1"
: >"$cwd/+literal_names_preset1"
pont="$(pwd)/pont.sh"

pont_in_cwd() {
	(cd "$cwd" && "$shell" "$pont" "$@")
}

in_each_shell() {
	for shell in sh dash bash; do
		command -v "$shell" >/dev/null || continue
		"$@"
	done
}

lists_module() {
	printf '%s\n' "$1" | grep -qxF -- "$module_name"
}

lists_module_without_lookalike() {
	lists_module "$1" && ! printf '%s\n' "$1" | grep -qxF -- 'literal_names1'
}

check_selected_lists() {
	result=$(pont_in_cwd -aL)
	lists_module_without_lookalike "$result" ||
		{ echo "$shell -aL expanded a module name as a glob: $result"; exit 1; }
	result=$(PONT_BASE_MODULES='literal_names_base[1]' pont_in_cwd -eL \
		"$module_name")
	[ "$result" = "literal_names_base[1]
$module_name" ] ||
		{ echo "$shell -eL expanded a base module as a glob: $result"; exit 1; }
	for suffix in '[1]' '*'; do
		result=$(pont_in_cwd -eL "+literal_names_preset$suffix")
		[ "$result" = "$module_name" ] || {
			echo "$shell -eL read another preset for $suffix: $result"
			exit 1
		}
	done
}

check_lists_after_install() {
	result=$(pont_in_cwd -iL)
	lists_module_without_lookalike "$result" ||
		{ echo "$shell -iL expanded a module name as a glob: $result"; exit 1; }
	result=$(pont_in_cwd -oL)
	! lists_module "$result" ||
		{ echo "$shell -oL listed a module right after $1"; exit 1; }
}

check_lists_after_change() {
	result=$(pont_in_cwd -oL)
	lists_module_without_lookalike "$result" ||
		{ echo "$shell -oL did not list a changed module: $result"; exit 1; }
}

check_yank() {
	rm -rf "$yank"
	mkdir -p "$yank"
	pont_in_cwd -y "$yank" '+literal_names_preset[1]' >/dev/null
	cmp -s "$presets/literal_names_preset[1].preset" \
		"$yank/literal_names_preset[1].preset" ||
		{ echo "$shell -y copied another preset"; exit 1; }
}

check_packages() {
	pont_in_cwd -fx 'literal_packages[1]' >/dev/null
	if [ ! -L "$PONT_TARGET/literal_packages_file" ] ||
		[ -L "$PONT_TARGET/literal_packages_inner_lookalike_file" ] ||
		[ -L "$PONT_TARGET/literal_packages_lookalike_file" ]; then
		echo "$shell -fx stowed other packages:"
		ls -A "$PONT_TARGET"
		exit 1
	fi
	pont_in_cwd -r 'literal_packages[1]' >/dev/null
	[ ! -L "$PONT_TARGET/literal_packages_file" ] ||
		{ echo "$shell -r did not unstow a package"; exit 1; }
}

$COVERAGE ./pont.sh -aL >/dev/null
PONT_BASE_MODULES='literal_names_base[1]' $COVERAGE ./pont.sh -eL \
	'+literal_names_preset[1]' >/dev/null
in_each_shell check_selected_lists

$COVERAGE ./pont.sh -y "$yank" '+literal_names_preset[1]' >/dev/null
in_each_shell check_yank

$COVERAGE ./pont.sh -fx "$module_name" >/dev/null
$COVERAGE ./pont.sh -iL >/dev/null
$COVERAGE ./pont.sh -oL >/dev/null
in_each_shell check_lists_after_install 'its install'

echo changed >"$module/dummyfile"
in_each_shell check_lists_after_change

cat >"$bin/sudo" <<'EOF'
#!/bin/sh
while :; do
	case $1 in
	--version) exit 0 ;;
	--preserve-env=* | -E) shift ;;
	-u) shift 2 ;;
	*) break ;;
	esac
done
exec "$@"
EOF
chmod +x "$bin/sudo"
SUDO_USER=$(id -un) PATH="$bin:$PATH" $COVERAGE ./pont.sh -fx "$module_name" \
	>/dev/null
in_each_shell check_lists_after_install 'its install under sudo'

$COVERAGE ./pont.sh -fx 'literal_packages[1]' >/dev/null
$COVERAGE ./pont.sh -r 'literal_packages[1]' >/dev/null
in_each_shell check_packages
