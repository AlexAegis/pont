#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Script names stay literal, and an install group runs only the scripts whose
# first segment is its name. Sourced scripts and condition files of scripts
# still run with globbing on, also after a module without install scripts.

module="$PONT_MODULES_HOME/literal_script_names"
first="$PONT_MODULES_HOME/literal_script_names_first"
log="$PONT_TARGET/literal_script_names.log"
cwd="$PONT_TARGET/literal_script_names"
trap 'rm -rf "$module" "$first"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module" "$first" "$cwd"
echo test >"$first/dummyfile"
for script in 1.user.sh 10.user.sh 21.user.sh '2[1].user.sh'; do
	cat >"$module/$script" <<'EOF'
#!/bin/sh
printf '%s\n' "${0##*/}" >>"$PONT_TARGET/literal_script_names.log"
EOF
	chmod +x "$module/$script"
done
cat >"$module/i.user.sh" <<'EOF'
case $- in
*f*) printf '%s\n' 'init without globbing' ;;
*) printf '%s\n' init ;;
esac >>"$PONT_TARGET/literal_script_names.log"
EOF
printf '%s\n' 'case $- in *f*) exit 1 ;; esac' >"$module/1.user.sh.condition"
: >"$cwd/21"
: >"$cwd/21.user.sh"
pont="$(pwd)/pont.sh"
expected=$(printf '%s\n' init 1.user.sh 10.user.sh 21.user.sh \
	'2[1].user.sh' | sort)

$COVERAGE ./pont.sh -fx literal_script_names_first literal_script_names \
	>/dev/null
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	rm -f "$log"
	(cd "$cwd" && "$shell" "$pont" -fx literal_script_names_first \
		literal_script_names >/dev/null)
	result=$(sort "$log")
	[ "$result" = "$expected" ] || {
		echo "$shell ran other scripts:"
		cat "$log"
		exit 1
	}
done
