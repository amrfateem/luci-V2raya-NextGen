#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# On-router test for the v2rayA NextGen packages. Run it on the router as
# root. It changes the service state (stop and start) and restores it.
#
# Usage: sh tests/router-test.sh [expected-v2raya-version]
#
# Exits non-zero if any check fails.

set -u

EXPECT_VERSION="${1:-}"
PASS=0
FAIL=0

ok() {
	PASS=$((PASS + 1))
	echo "PASS  $1"
}

bad() {
	FAIL=$((FAIL + 1))
	echo "FAIL  $1"
}

check() {
	desc="$1"
	shift
	if "$@" >/dev/null 2>&1; then
		ok "$desc"
	else
		bad "$desc"
	fi
}

core_running() {
	ps w | grep -v grep | grep -q '/usr/bin/v2raya_core'
}

wait_for() {
	i=0
	while [ "$i" -lt 60 ]; do
		"$@" && return 0
		sleep 1
		i=$((i + 1))
	done
	return 1
}

tables_up() {
	nft list tables 2>/dev/null | grep -q 'table inet v2raya$'
}

tables_down() {
	! nft list tables 2>/dev/null | grep -q 'table inet v2raya'
}

direct_ip() {
	curl -4 -sS --max-time 15 --interface wan https://ipinfo.io/ip 2>/dev/null
}

proxy_ip() {
	curl -4 -sS --max-time 15 https://ipinfo.io/ip 2>/dev/null
}

echo "== static"
check "v2raya package installed" apk info -e v2raya
check "luci-app-v2raya-nextgen installed" apk info -e luci-app-v2raya-nextgen
if [ -n "$EXPECT_VERSION" ]; then
	check "v2raya version is $EXPECT_VERSION" sh -c "apk list -I v2raya | awk '{ print \$1 }' | grep -qx 'v2raya-$EXPECT_VERSION'"
fi
check "service script present" test -x /etc/init.d/v2raya
check "boot link present" test -L /etc/rc.d/S99v2raya
check "ACL is valid JSON" jsonfilter -i /usr/share/rpcd/acl.d/luci-app-v2raya.json -e '@'
check "overview helper present" test -x /usr/libexec/v2raya-detect
check "enable helper present" test -x /usr/libexec/luci-app-v2raya/enable
check "firewall includes WAN masquerade" sh -c "nft list table inet fw4 | grep -q masquerade"
check "firewall loads without warnings" sh -c "! fw4 print 2>&1 | grep -q '\[!\]'"

echo "== proxy running"
if ! core_running; then
	/etc/init.d/v2raya start >/dev/null 2>&1
fi
check "v2raya_core is running" wait_for core_running
check "transparent proxy tables are up" wait_for tables_up
PROXY_1=$(proxy_ip)
DIRECT_1=$(direct_ip)
check "proxy path answers" test -n "$PROXY_1"
check "direct path answers" test -n "$DIRECT_1"
check "proxy and direct exit IPs differ" test "$PROXY_1" != "$DIRECT_1"

echo "== stop"
/etc/init.d/v2raya stop >/dev/null 2>&1
sleep 3
check "no inet v2raya table after stop" tables_down
check "no inet v2raya_dns table after stop" sh -c "! nft list tables 2>/dev/null | grep -q v2raya_dns"
check "no fwmark policy rule after stop" sh -c "! ip rule show | grep -q 'fwmark 0x40/0xc0'"
check "firewall still masquerades after stop" sh -c "nft list table inet fw4 | grep -q masquerade"
DIRECT_2=$(proxy_ip)
check "internet works after stop" test -n "$DIRECT_2"
check "traffic is direct after stop" test "$DIRECT_2" = "$DIRECT_1"

echo "== start"
/etc/init.d/v2raya start >/dev/null 2>&1
check "v2raya_core is running after start" wait_for core_running
check "transparent proxy tables are up after start" wait_for tables_up
PROXY_2=$(proxy_ip)
check "traffic goes through the proxy after start" sh -c "test -n '$PROXY_2' && test '$PROXY_2' != '$DIRECT_1'"

echo "== DNS"
check "router resolves names through dnsmasq" sh -c "nslookup openwrt.org 2>/dev/null | grep -q '^Address'"

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
