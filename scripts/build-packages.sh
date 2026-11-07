#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Build the v2rayA NextGen packages for one OpenWrt release and target with
# the official OpenWrt SDK.
#
# This script builds .ipk/.apk packages.  It does not build OpenWrt firmware
# and it does not create an OpenWrt source tree.
#
# Usage:
#   ./scripts/build-packages.sh <openwrt-version> <target> [package ...]
#
# Examples:
#   ./scripts/build-packages.sh 25.12.6 x86/64
#   ./scripts/build-packages.sh 24.10.8 ramips/mt7621
#
# Environment:
#   V2RAYA_NG_BUILD_DIR  Base directory for the SDK cache and build tree
#                        (default: ${TMPDIR:-/tmp}/v2raya-nextgen-build)
#   SDK_CACHE            Directory for downloaded SDK archives
#   WORK_DIR             Directory for extracted SDKs
#   OPENWRT_MIRROR       Download mirror (default: https://downloads.openwrt.org)
#   FEEDS_TO_UPDATE      Feeds to fetch (default: "base packages luci", or "all")
#   SKIP_FEEDS_UPDATE    Set to 1 to reuse the feeds already in the SDK
#
# The build tree deliberately lives outside the repository: the SDK adds this
# repository as a feed, and a SDK directory inside the feed root makes the
# feed scanner walk into itself.  It also keeps the case-sensitive build on a
# Linux filesystem when the checkout is on a case-insensitive mount (WSL).
#
# The script is intentionally Linux-only.  GitHub Actions and WSL both work.

set -eu

usage() {
	echo "Usage: $0 <openwrt-version> <target> [package ...]" >&2
	echo "Example: $0 25.12.6 x86/64" >&2
	exit 1
}

[ $# -ge 2 ] || usage

OPENWRT_VERSION="$1"
OPENWRT_TARGET="$2"
shift 2

DEFAULT_PACKAGES="v2raya v2raya-core v2raya-geoip v2raya-geosite luci-app-v2raya"
PACKAGES="${*:-$DEFAULT_PACKAGES}"

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_ROOT="${V2RAYA_NG_BUILD_DIR:-${TMPDIR:-/tmp}/v2raya-nextgen-build}"
SDK_CACHE="${SDK_CACHE:-$BUILD_ROOT/sdk-cache}"
WORK_DIR="${WORK_DIR:-$BUILD_ROOT/work}"
TARGET_SLUG=$(printf '%s' "$OPENWRT_TARGET" | tr '/' '-')
OPENWRT_MIRROR="${OPENWRT_MIRROR:-https://downloads.openwrt.org}"
BASE_URL="${OPENWRT_MIRROR%/}/releases/${OPENWRT_VERSION}/targets/${OPENWRT_TARGET}"

need() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "Missing required command: $1" >&2
		exit 1
	}
}

need curl
need tar
need grep
need make

mkdir -p "$SDK_CACHE" "$WORK_DIR"

echo "==> Resolving SDK for OpenWrt ${OPENWRT_VERSION} ${OPENWRT_TARGET}"
INDEX=$(curl --http1.1 -fsSL --retry 5 --retry-all-errors --retry-delay 2 "$BASE_URL/")
SDK_NAME=$(printf '%s\n' "$INDEX" | grep -oE 'openwrt-sdk-[^"]*\.tar\.(zst|xz)' | head -n 1)

[ -n "$SDK_NAME" ] || {
	echo "Could not find an SDK archive at $BASE_URL" >&2
	exit 1
}

SDK_ARCHIVE="$SDK_CACHE/$SDK_NAME"
if [ ! -f "$SDK_ARCHIVE" ]; then
	echo "==> Downloading $SDK_NAME"
	curl --http1.1 -fL --retry 5 --retry-all-errors --retry-delay 2 \
		--silent --show-error -o "$SDK_ARCHIVE.part" "$BASE_URL/$SDK_NAME"
	mv "$SDK_ARCHIVE.part" "$SDK_ARCHIVE"
fi

SDK_DIR="$WORK_DIR/sdk-${OPENWRT_VERSION}-${TARGET_SLUG}"
if [ ! -d "$SDK_DIR" ]; then
	echo "==> Extracting SDK"
	EXTRACT_DIR="$WORK_DIR/extract-${OPENWRT_VERSION}-${TARGET_SLUG}"
	rm -rf "$EXTRACT_DIR"
	mkdir -p "$EXTRACT_DIR"
	case "$SDK_NAME" in
	*.tar.zst) tar --zstd -xf "$SDK_ARCHIVE" -C "$EXTRACT_DIR" ;;
	*.tar.xz) tar -xJf "$SDK_ARCHIVE" -C "$EXTRACT_DIR" ;;
	*) tar -xf "$SDK_ARCHIVE" -C "$EXTRACT_DIR" ;;
	esac
	EXTRACTED=$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d -name 'openwrt-sdk-*' | head -n 1)
	[ -n "$EXTRACTED" ] || {
		echo "SDK archive did not contain an openwrt-sdk-* directory" >&2
		exit 1
	}
	mv "$EXTRACTED" "$SDK_DIR"
	rmdir "$EXTRACT_DIR"
else
	echo "==> Reusing SDK at $SDK_DIR"
fi

cd "$SDK_DIR"

if ! grep -q '^src-link v2raya_nextgen ' feeds.conf.default; then
	echo "==> Adding the v2rayA NextGen feed"
	printf '\nsrc-link v2raya_nextgen %s\n' "$ROOT" >>feeds.conf.default
fi

echo "==> Updating feeds"
if [ "${SKIP_FEEDS_UPDATE:-0}" != "1" ]; then
	FEEDS_TO_UPDATE="${FEEDS_TO_UPDATE:-base packages luci}"
	if [ "$FEEDS_TO_UPDATE" = "all" ]; then
		./scripts/feeds update -a
	else
		# shellcheck disable=SC2086
		./scripts/feeds update $FEEDS_TO_UPDATE
		./scripts/feeds update v2raya_nextgen
	fi
else
	echo "    skipped (SKIP_FEEDS_UPDATE=1)"
fi

echo "==> Installing the Go toolchain and v2rayA packages"
./scripts/feeds install golang
./scripts/feeds install -a -p base
./scripts/feeds install -a -p luci
for pkg in $PACKAGES; do
	./scripts/feeds install -f -p v2raya_nextgen "$pkg"
done

echo "==> Preparing configuration"
make defconfig

for pkg in $PACKAGES; do
	echo "==> Building $pkg"
	make -j"$(nproc)" "package/$pkg/compile" V=s
done

echo "==> Collecting packages"
ARCH=$(find bin/packages -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -n 1)
[ -n "$ARCH" ] || {
	echo "Could not determine the built package architecture" >&2
	exit 1
}

APP_VERSION=$(cat "$ROOT/VERSION" 2>/dev/null || sed -n 's/^PKG_VERSION:=//p' "$ROOT/v2raya/Makefile" | head -n 1)
OUT_DIR="$ROOT/dist/openwrt-${OPENWRT_VERSION}-${ARCH}"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

for pkg in $PACKAGES; do
	find bin/packages -type f \( -name "${pkg}_*.ipk" -o -name "${pkg}-*.apk" \) \
		-exec cp -f {} "$OUT_DIR/" \;
done

COUNT=$(find "$OUT_DIR" -maxdepth 1 -type f | wc -l)
[ "$COUNT" -gt 0 ] || {
	echo "No packages were produced for $OPENWRT_VERSION $OPENWRT_TARGET" >&2
	exit 1
}

ARCHIVE="$ROOT/dist/v2raya-nextgen-${APP_VERSION}-openwrt-${OPENWRT_VERSION}-${ARCH}.tar.gz"
tar -czf "$ARCHIVE" -C "$OUT_DIR" .

echo
echo "==> Built packages for OpenWrt ${OPENWRT_VERSION} ${OPENWRT_TARGET} (${ARCH})"
ls -1 "$OUT_DIR"
echo "==> Archive: $ARCHIVE"
