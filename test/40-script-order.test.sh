#!/bin/sh
set -e
# shellcheck disable=SC1091
. ./test/env.sh
# Install groups run in the order of the number of their first segment. The
# scripts of every listing run in byte order, in every locale.

module="$PONT_MODULES_HOME/script_order"
log="$PONT_TARGET/script_order.log"
trap 'rm -rf "$module"' EXIT
trap 'trap "" HUP INT TERM; exit 1' HUP INT TERM
mkdir -p "$module"
export script_order_a=1 script_order_B=1
# shellcheck disable=SC2016
for script in e.user.sh env.user.sh i.user.sh init.user.sh 1.user.sh \
	2.user.sh 10.user.sh 01.user.sh '1.user.$script_order_a.sh' \
	'1.user.$script_order_B.sh' u.user.sh update.user.sh r.user.sh \
	remove.user.sh; do
	printf '%s\n' "printf '%s\\n' '$script' >>\"\$PONT_TARGET/script_order.log\"" \
		>"$module/$script"
	chmod +x "$module/$script"
done

expect_log() {
	result=$(cat "$log")
	[ "$result" = "$(printf '%s\n' "$@")" ] ||
		fail "pont -$flags in locale $locale ran the scripts in this order:
$result"
}

$COVERAGE ./pont.sh -fx script_order >/dev/null
locales=C
if locale -a 2>/dev/null | grep -qi '^en_US\.utf-\{0,1\}8$'; then
	locales="$locales en_US.UTF-8"
else
	echo "Locale en_US.UTF-8 not available, checked only C"
fi
for locale in $locales; do
	flags=fx
	rm -f "$log"
	LC_ALL=$locale ./pont.sh -$flags script_order >/dev/null
	# shellcheck disable=SC2016
	expect_log e.user.sh env.user.sh i.user.sh init.user.sh 01.user.sh \
		'1.user.$script_order_B.sh' '1.user.$script_order_a.sh' 1.user.sh \
		2.user.sh 10.user.sh
	flags=u
	rm -f "$log"
	LC_ALL=$locale ./pont.sh -$flags script_order >/dev/null
	expect_log e.user.sh env.user.sh u.user.sh update.user.sh
	flags=rr
	rm -f "$log"
	LC_ALL=$locale ./pont.sh -$flags script_order >/dev/null
	expect_log e.user.sh env.user.sh r.user.sh remove.user.sh
done
