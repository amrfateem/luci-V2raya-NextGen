#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Install the latest v2rayA NextGen release on an OpenWrt router.
#
# Usage:
#   sh install.sh
#
# Environment:
#   V2RAYA_NG_REPO     GitHub repository (owner/name)
#   V2RAYA_NG_VERSION  Release tag to install (default: latest)
#   V2RAYA_NG_START    Set to 1 to enable and start the service after install
#   V2RAYA_NG_GEODATA  Set to 1 to install the optional GeoIP/GeoSite packages
#   V2RAYA_NG_STRICT   Set to 1 to refuse if another proxy service is enabled
#   V2RAYA_NG_DRY_RUN  Set to 1 to run the checks and exit before downloading
#
# Previous NextGen split packages (-nextgen names) are removed automatically,
# and an older canonical v2raya package is upgraded in place. Keep a backup of
# /etc/v2raya before installing on a production router.

set -eu

REPO="${V2RAYA_NG_REPO:-AmrFateem/luci-V2raya-NextGen}"
WANT_VERSION="${V2RAYA_NG_VERSION:-latest}"
START_AFTER="${V2RAYA_NG_START:-0}"
GEODATA="${V2RAYA_NG_GEODATA:-0}"
STRICT="${V2RAYA_NG_STRICT:-0}"
DRY_RUN="${V2RAYA_NG_DRY_RUN:-0}"

die() {
	echo "Error: $*" >&2
	exit 1
}

need() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

[ -f /etc/openwrt_release ] || die "this does not look like an OpenWrt system"

. /etc/openwrt_release

ARCH="${DISTRIB_ARCH:-}"
RELEASE="${DISTRIB_RELEASE:-}"
[ -n "$ARCH" ] && [ -n "$RELEASE" ] || die "DISTRIB_ARCH or DISTRIB_RELEASE is missing"

RELEASE_SERIES=$(printf '%s' "$RELEASE" | awk -F. '{ print $1 "." $2 }')

need tar

WORK=$(mktemp -d 2>/dev/null || mktemp -d -t v2raya-ng)
trap 'rm -rf "$WORK"' EXIT

first_bin() {
	for path in "$@"; do
		if [ -x "$path" ]; then
			printf '%s' "$path"
			return 0
		fi
	done
	return 1
}

list_packages() {
	if command -v opkg >/dev/null 2>&1; then
		opkg list-installed 2>/dev/null | awk '{ print $1 }'
	elif command -v apk >/dev/null 2>&1; then
		apk info 2>/dev/null
	fi
}

packages=$(list_packages)

has_package() {
	printf '%s\n' "$packages" | grep -qx "$1"
}

package_version() {
	if command -v opkg >/dev/null 2>&1; then
		opkg list-installed "$1" 2>/dev/null | awk '{ print $3 }' | sed -n '1p'
	elif [ -f /lib/apk/db/installed ]; then
		awk -v p="$1" '$0 == "P:" p { getline; sub(/^V:/, ""); print; exit }' \
			/lib/apk/db/installed
	fi
}

# Return true when version $1 is lower than version $2.
version_lt() {
	[ -n "$1" ] || return 0
	awk -v a="$1" -v b="$2" 'BEGIN {
		n = split(a, x, "."); m = split(b, y, ".");
		for (i = 1; i <= 3; i++) {
			xs = (i <= n) ? x[i] : 0;
			ys = (i <= m) ? y[i] : 0;
			sub(/-.*/, "", xs); sub(/-.*/, "", ys);
			if (xs + 0 < ys + 0) exit 0;
			if (xs + 0 > ys + 0) exit 1;
		}
		exit 1;
	}'
}

# Older builds of this feed used -nextgen package names that own the same
# files as the canonical packages, so they have to go before the upgrade.
LEGACY_PACKAGES=""
for pkg in v2raya-nextgen v2raya-core-nextgen luci-app-v2raya-nextgen; do
	has_package "$pkg" && LEGACY_PACKAGES="$LEGACY_PACKAGES $pkg"
done

if [ -n "$LEGACY_PACKAGES" ]; then
	echo "==> Removing previous NextGen split packages:$LEGACY_PACKAGES"

	if [ "$DRY_RUN" = "1" ]; then
		echo "    dry run: would remove them before installing"
	else
		/etc/init.d/v2raya stop >/dev/null 2>&1 || true
		cp -p /etc/config/v2raya "$WORK/v2raya.config" 2>/dev/null || true

		if command -v apk >/dev/null 2>&1 && [ -d /etc/apk ]; then
			# shellcheck disable=SC2086
			apk del $LEGACY_PACKAGES
		else
			# shellcheck disable=SC2086
			opkg remove $LEGACY_PACKAGES
		fi

		if [ -f "$WORK/v2raya.config" ] && [ ! -f /etc/config/v2raya ]; then
			cp -p "$WORK/v2raya.config" /etc/config/v2raya
		fi

		packages=$(list_packages)
	fi
fi

if [ -x /usr/bin/v2raya ] || [ -x /usr/bin/v2raya_core ]; then
	if ! has_package v2raya && ! has_package v2raya-core; then
		echo "==> Manual v2rayA binaries detected"
		echo "    /usr/bin/v2raya and/or /usr/bin/v2raya_core exist without the"
		echo "    packaged pair. Installing will replace those files. Back up"
		echo "    /etc/v2raya first."
	fi
fi

# The old OpenWrt feed ships 2.2.7 under the canonical names.  A same-name
# package upgrade replaces it, so this only needs a warning, not a refusal.
if has_package v2raya; then
	current_version=$(package_version v2raya)
	if version_lt "$current_version" "2.5"; then
		echo "==> Older v2raya package detected: $current_version"
		echo "    It will be upgraded in place. Back up /etc/v2raya first;"
		echo "    the service migrates the old database on its first start."
	fi
fi

echo "==> Checking for existing proxy cores"
for spec in \
	"Xray-core xray-core /usr/bin/xray /usr/sbin/xray /usr/bin/xray-core" \
	"sing-box sing-box /usr/bin/sing-box /usr/sbin/sing-box /usr/bin/singbox" \
	"v2ray-core v2ray-core /usr/bin/v2ray /usr/sbin/v2ray /usr/bin/v2ray-core"; do

	set -- $spec
	label="$1"
	package="$2"
	shift 2
	binary=$(first_bin "$@") || binary=""

	if [ -n "$binary" ] || has_package "$package"; then
		printf '    %-12s %s' "$label" "${binary:-binary not found}"
		has_package "$package" && printf ' (package installed)'
		printf '\n'
	fi
done
echo "    v2rayA uses /usr/bin/v2raya_core and will not replace or start those binaries."

proxy_present=""
proxy_enabled=""
for service in xray sing-box v2ray passwall passwall2 ssrplus openclash shellcrash mihomo clash byedpi; do
	[ -x "/etc/init.d/$service" ] || continue
	proxy_present="${proxy_present}${proxy_present:+,}$service"

	if "/etc/init.d/$service" enabled >/dev/null 2>&1; then
		proxy_enabled="${proxy_enabled}${proxy_enabled:+,}$service"
	fi
done

if [ -n "$proxy_present" ]; then
	echo "    Existing proxy services: $proxy_present"
fi

if [ -n "$proxy_enabled" ]; then
	echo "    WARNING: enabled at boot: $proxy_enabled"
	echo "    Run only one transparent-proxy stack, otherwise duplicate nftables/iptables"
	echo "    rules will fight each other."

	if [ "$STRICT" = "1" ]; then
		die "another proxy service is enabled; disable it or unset V2RAYA_NG_STRICT"
	fi
fi

if [ "$DRY_RUN" = "1" ]; then
	echo "==> Dry run: checks complete, nothing downloaded or installed"
	exit 0
fi

# curl is not part of the OpenWrt base system.  Prefer it when present, but
# fall back to the default uclient-fetch (or a full wget).
fetch_to() {
	url="$1"
	out="$2"

	if command -v curl >/dev/null 2>&1; then
		curl --http1.1 -fL --retry 5 --retry-all-errors --retry-delay 2 \
			--silent --show-error -o "$out" "$url"
	elif command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$out" "$url"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$out" "$url"
	else
		die "curl, uclient-fetch or wget is required"
	fi
}

fetch_stdout() {
	fetch_to "$1" "$WORK/fetch.tmp"
	cat "$WORK/fetch.tmp"
}

if [ "$WANT_VERSION" = "latest" ]; then
	API="https://api.github.com/repos/${REPO}/releases/latest"
else
	API="https://api.github.com/repos/${REPO}/releases/tags/${WANT_VERSION}"
fi

echo "==> Looking up v2rayA NextGen for OpenWrt ${RELEASE} (${ARCH})"
RELEASE_JSON=$(fetch_stdout "$API") || die "could not read the GitHub release"

if command -v jsonfilter >/dev/null 2>&1; then
	URLS=$(printf '%s' "$RELEASE_JSON" | jsonfilter -e '@.assets[*].browser_download_url')
	TAG=$(printf '%s' "$RELEASE_JSON" | jsonfilter -e '@.tag_name')
else
	URLS=$(printf '%s' "$RELEASE_JSON" | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')
	TAG=$(printf '%s' "$RELEASE_JSON" | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p')
fi

[ -n "$URLS" ] || die "the release has no downloadable assets"

# Prefer an archive built for this exact OpenWrt series and CPU architecture.
ARCHIVE_URL=$(printf '%s\n' "$URLS" |
	grep -E "v2raya-nextgen-.*-openwrt-${RELEASE_SERIES}\.[0-9]+-${ARCH}\.tar\.gz$" |
	head -n 1)

# Fall back to any archive for this architecture.  Go binaries built with
# CGO disabled are self-contained, so a package from a neighbouring OpenWrt
# release usually runs fine; mips/loong64 builds are dynamically linked and
# should use the exact series.
if [ -z "$ARCHIVE_URL" ]; then
	ARCHIVE_URL=$(printf '%s\n' "$URLS" |
		grep -E "v2raya-nextgen-.*-${ARCH}\.tar\.gz$" |
		head -n 1)
fi

[ -n "$ARCHIVE_URL" ] || die "no release archive found for ${ARCH}"

ARCHIVE="$WORK/packages.tar.gz"
echo "==> Downloading $(basename "$ARCHIVE_URL")"
fetch_to "$ARCHIVE_URL" "$ARCHIVE"

# Verify the release checksum when the maintainers published one.
SUMS_URL="$(dirname "$ARCHIVE_URL")/SHA256SUMS"
if fetch_to "$SUMS_URL" "$WORK/SHA256SUMS" 2>/dev/null; then
	(
		cd "$WORK"
		grep " $(basename "$ARCHIVE_URL")\$" SHA256SUMS >SHA256SUMS.one 2>/dev/null || true
		if [ -s SHA256SUMS.one ]; then
			sha256sum -c SHA256SUMS.one >/dev/null 2>&1 || die "checksum verification failed"
			echo "    checksum OK"
		fi
	)
fi

echo "==> Extracting"
mkdir -p "$WORK/packages"
tar -xzf "$ARCHIVE" -C "$WORK/packages"

if [ "$GEODATA" != "1" ]; then
	rm -f "$WORK"/packages/v2raya-geoip* "$WORK"/packages/v2raya-geosite*
fi

if command -v apk >/dev/null 2>&1 && [ -d /etc/apk ]; then
	echo "==> Installing with apk"
	apk add --allow-untrusted "$WORK"/packages/*.apk
elif command -v opkg >/dev/null 2>&1; then
	echo "==> Installing with opkg"
	opkg update >/dev/null 2>&1 || true
	opkg install --force-reinstall "$WORK"/packages/*.ipk
else
	die "neither apk nor opkg was found"
fi

/etc/init.d/v2raya enable >/dev/null 2>&1 || true

if [ "$START_AFTER" = "1" ]; then
	uci set v2raya.config.enabled='1'
	uci commit v2raya
	/etc/init.d/v2raya restart
fi

PORT=$(uci get v2raya.config.address 2>/dev/null | awk -F: '{ print $NF }')
[ -n "$PORT" ] || PORT=2017
HOST=$(uci get network.lan.ipaddr 2>/dev/null || echo "this router")

cat <<EOF

v2rayA NextGen ${TAG} is installed.

  Web UI:  http://${HOST}:${PORT}
  Enable:  uci set v2raya.config.enabled='1' && uci commit v2raya
  Start:   /etc/init.d/v2raya restart
  Or use:  LuCI -> Services -> v2rayA

The web UI is exposed on all interfaces by default.  Set a password on the
first visit, or change the listening address to 127.0.0.1:2017.
EOF

if [ "$GEODATA" != "1" ]; then
	echo
	echo "GeoIP/GeoSite data was not installed."
	echo "v2rayA downloads it on first start; if the router is offline, install"
	echo "v2raya-geoip and v2raya-geosite or rerun with V2RAYA_NG_GEODATA=1."
fi
