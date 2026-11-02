#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Log lines print their colors as escape codes in every shell, also the colors
# inside a message, and never as the text \033

module="$PONT_MODULES_HOME/log_colors"
trap 'rm -rf "$module"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module"
printf '%s\n' '#!/bin/sh' >"$module/1.user.sh"
chmod +x "$module/1.user.sh"
esc=$(printf '\033')

$COVERAGE ./pont.sh -v -x log_colors >/dev/null 2>&1
pont="$(pwd)/pont.sh"
for shell in sh dash bash; do
	command -v "$shell" >/dev/null || continue
	rm -f "$module/.tarhash"
	logs=$("$shell" "$pont" -v -x log_colors 2>&1 >/dev/null)
	logs="$logs
$("$shell" "$pont" -v -x log_colors 2>&1 >/dev/null)"
	case $logs in
	*'\033'*) printf '%s\n' "$shell logged the text \\033: $logs"; exit 1 ;;
	esac
	success="Successfully installed log_colors"
	for text in "${esc}[0;36m[  Trace  ]: ${esc}[0;31mhash mismatch" \
		"${esc}[0;36m[  Trace  ]: ${esc}[0;32mhash match" \
		"${esc}[0;32m[ Success ]: $success${esc}[0m"; do
		printf '%s\n' "$logs" | grep -qF -- "$text" ||
			{ printf '%s\n' "$shell did not log: $text"; exit 1; }
	done
done
