#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Add the v2rayA package feed to this OpenWrt router, then install the
# versions the feed serves. Run on the router as root. Running it again
# updates the packages.
#
# Supports apk (OpenWrt 25.12+) and opkg (OpenWrt 23.05 / 24.10).
#
# Usage:
#   sh feed-setup.sh

set -eu

REPO="AmrFateem/luci-V2raya-NextGen"
RAW="https://raw.githubusercontent.com/$REPO/main"
ARCH=$(sed -n "s/^DISTRIB_ARCH='\(.*\)'/\1/p" /etc/openwrt_release)
RELEASE=$(sed -n "s/^DISTRIB_RELEASE='\(.*\)'/\1/p" /etc/openwrt_release)
[ -n "$ARCH" ] || { echo "Error: cannot read DISTRIB_ARCH" >&2; exit 1; }

if command -v apk >/dev/null 2>&1; then
	mkdir -p /etc/apk/keys /etc/apk/repositories.d
	wget -qO /etc/apk/keys/v2raya-feed.pem "$RAW/feed/public-key.pem"
	echo "https://raw.githubusercontent.com/$REPO/feed/$ARCH/packages.adb" \
		> /etc/apk/repositories.d/v2raya.list
	apk update
	# Replace the old LuCI app package; the new one conflicts with it.
	if apk info -e luci-app-v2raya >/dev/null 2>&1; then
		apk del luci-app-v2raya
	fi
	# Pin the exact versions the feed serves. A plain `apk upgrade` would
	# also upgrade unrelated OpenWrt packages.
	pins=$(wget -qO- "$RAW/feed/latest" | sed 's/^/ /' | tr -d '\n')
	[ -n "$pins" ] || { echo "Error: cannot read feed/latest" >&2; exit 1; }
	# shellcheck disable=SC2086
	if ! apk add $pins; then
		echo "Pinned versions are not in the feed yet; installing the latest."
		apk add v2raya v2raya-core luci-app-v2raya-nextgen
	fi
	echo "v2rayA is at: $(apk list -I v2raya | awk '{ print $1 }')"
elif command -v opkg >/dev/null 2>&1; then
	[ -n "$RELEASE" ] || { echo "Error: cannot read DISTRIB_RELEASE" >&2; exit 1; }
	MAJOR_MINOR=${RELEASE%.*}
	mkdir -p /etc/opkg
	touch /etc/opkg/customfeeds.conf
	sed -i '/v2raya/d' /etc/opkg/customfeeds.conf
	echo "src/gz v2raya https://raw.githubusercontent.com/$REPO/feed/opkg/$MAJOR_MINOR/$ARCH" \
		>> /etc/opkg/customfeeds.conf
	# Install the usign key that signs the opkg index. The key ID is the
	# usign fingerprint of feed/opkg.pub; change both together.
	OPKG_KEY_ID=955262cbfde16422
	wget -qO /tmp/v2raya-opkg.pub "$RAW/feed/opkg.pub"
	if command -v usign >/dev/null 2>&1; then
		key_fp=$(usign -F -p /tmp/v2raya-opkg.pub)
		[ "$key_fp" = "$OPKG_KEY_ID" ] || {
			echo "Error: unexpected opkg feed key $key_fp" >&2
			rm -f /tmp/v2raya-opkg.pub
			exit 1
		}
	fi
	if command -v opkg-key >/dev/null 2>&1 &&
		command -v usign >/dev/null 2>&1; then
		opkg-key add /tmp/v2raya-opkg.pub
	else
		mkdir -p /etc/opkg/keys
		cp /tmp/v2raya-opkg.pub "/etc/opkg/keys/$OPKG_KEY_ID"
	fi
	rm -f /tmp/v2raya-opkg.pub
	opkg update
	if opkg list-installed luci-app-v2raya 2>/dev/null | grep -q '^luci-app-v2raya '; then
		opkg remove luci-app-v2raya
	fi
	opkg install v2raya v2raya-core luci-app-v2raya-nextgen
	echo "v2rayA is at: $(opkg list-installed v2raya | awk '{ print $1 }')"
else
	echo "Error: neither apk nor opkg found" >&2
	exit 1
fi
