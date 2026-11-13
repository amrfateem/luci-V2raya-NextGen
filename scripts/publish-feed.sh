#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Publish the signed package feed.
#
# The feed lives on the `feed` branch, as one commit holding the current
# packages only. It is served by raw.githubusercontent.com, which routers can
# reach. The project code stays on main.
#
# Usage:
#   # apk (OpenWrt 25.12+)
#   sh scripts/publish-feed.sh <apk-dir> <arch>
#
#   # opkg (OpenWrt 23.05 / 24.10)
#   sh scripts/publish-feed.sh <ipk-dir> <arch> <release>   # e.g. 24.10
#
# Environment:
#   V2RAYA_FEED_KEY_FILE  private key used to sign the apk indexes
#   V2RAYA_OPKG_KEY_FILE  usign private key used to sign the opkg indexes
#   APK_BIN               apk binary (default: apk from PATH)
#   USIGN_BIN             usign binary (default: usign from PATH)
#
# The directory must hold exactly one version of each package. The private
# signing keys are never stored in this repository.

set -eu

REPO="AmrFateem/luci-V2raya-NextGen"
BRANCH="feed"

die() {
	echo "Error: $*" >&2
	exit 1
}

[ $# -ge 2 ] || die "usage: sh scripts/publish-feed.sh <pkg-dir> <arch> [release]"
PKG_DIR="$1"
ARCH="$2"
RELEASE="${3:-}"
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

TOKEN="${GITHUB_TOKEN:?set GITHUB_TOKEN to a token with repo access}"
if [ -n "$RELEASE" ]; then
	MODE=opkg
	OPKG_KEY="${V2RAYA_OPKG_KEY_FILE:-${V2RAYA_OPKG_KEY:?set V2RAYA_OPKG_KEY_FILE to the usign key}}"
	[ -f "$OPKG_KEY" ] || die "$OPKG_KEY is not a file"
	USIGN_BIN="${USIGN_BIN:-usign}"
	if [ -x "$USIGN_BIN" ]; then
		:
	elif command -v "$USIGN_BIN" >/dev/null 2>&1; then
		:
	else
		die "cannot run usign (set USIGN_BIN)"
	fi
	OPKG_PUBKEY="$ROOT/feed/opkg.pub"
	[ -f "$OPKG_PUBKEY" ] || die "missing $OPKG_PUBKEY"
	opkg_pub_fp=$("$USIGN_BIN" -F -p "$OPKG_PUBKEY")
	opkg_sec_fp=$("$USIGN_BIN" -F -s "$OPKG_KEY")
	[ "$opkg_pub_fp" = "$opkg_sec_fp" ] ||
		die "feed/opkg.pub ($opkg_pub_fp) does not match the opkg signing key ($opkg_sec_fp)"
	for tool in git tar gzip sha256sum; do
		command -v "$tool" >/dev/null 2>&1 || die "missing $tool"
	done
else
	MODE=apk
	APK_KEY="${V2RAYA_FEED_KEY_FILE:-${V2RAYA_FEED_KEY:?set V2RAYA_FEED_KEY_FILE to the signing key}}"
	[ -f "$APK_KEY" ] || die "$APK_KEY is not a file"
	APK_BIN="${APK_BIN:-apk}"
	if [ -x "$APK_BIN" ]; then
		:
	elif command -v "$APK_BIN" >/dev/null 2>&1; then
		:
	else
		die "cannot run apk (set APK_BIN)"
	fi
	command -v git >/dev/null 2>&1 || die "missing git"
fi

WORK=$(mktemp -d 2>/dev/null || mktemp -d -t v2raya-feed)
trap 'rm -rf "$WORK"' EXIT

URL="https://github.com/$REPO.git"
AUTH="Authorization: Basic $(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')"
git_auth() {
	git -c "http.extraHeader=$AUTH" "$@"
}

PKG="$WORK/pkg"
mkdir -p "$PKG"

copy_one() {
	name="$1"
	pattern="$2"
	count=$(ls "$PKG_DIR"/$pattern 2>/dev/null | wc -l)
	[ "$count" -eq 1 ] || die "$PKG_DIR must hold exactly one $name package (found $count)"
	cp "$PKG_DIR"/$pattern "$PKG/"
}

if [ "$MODE" = apk ]; then
	copy_one v2raya 'v2raya-[0-9]*.apk'
	copy_one v2raya-core 'v2raya-core-[0-9]*.apk'
	copy_one luci-app-v2raya-nextgen 'luci-app-v2raya-nextgen-[0-9]*.apk'
	"$APK_BIN" mkndx --allow-untrusted --sign-key "$APK_KEY" -o "$PKG/packages.adb" "$PKG"/*.apk
	version_of() {
		base=$(basename "$(ls "$PKG"/"$1"-[0-9]*.apk | head -n 1)" .apk)
		printf '%s\n' "${base#"$1"-}"
	}
else
	copy_one v2raya 'v2raya_[0-9]*.ipk'
	copy_one v2raya-core 'v2raya-core_[0-9]*.ipk'
	copy_one luci-app-v2raya-nextgen 'luci-app-v2raya-nextgen_[0-9]*.ipk'
	# Build the opkg index from each package's control file.
	(
		cd "$PKG"
		for ipk in *.ipk; do
			tar -xzf "$ipk" -O ./control.tar.gz | tar -xzO ./control |
				awk -v fn="$ipk" \
					-v size="$(stat -c%s "$ipk")" \
					-v sum="$(sha256sum "$ipk" | awk '{ print $1 }')" '
					/^Description:/ { desc = $0 "\n"; in_desc = 1; next }
					in_desc && /^[ \t]/ { desc = desc $0 "\n"; next }
					in_desc { in_desc = 0 }
					{ print }
					END {
						printf "Filename: %s\nSize: %s\nSHA256sum: %s\n%s", fn, size, sum, desc
					}
				'
			echo
		done > Packages
		"$USIGN_BIN" -S -m Packages -s "$OPKG_KEY" -x Packages.sig
		gzip -9c Packages > Packages.gz
	)
	version_of() {
		base=$(basename "$(ls "$PKG"/"$1"_[0-9]*.ipk | head -n 1)" .ipk)
		base=${base#"$1"_}
		printf '%s\n' "${base%%_*}"
	}
fi

V_SERVICE=$(version_of v2raya)
V_CORE=$(version_of v2raya-core)
V_LUCI=$(version_of luci-app-v2raya-nextgen)
echo "feed $MODE $ARCH ${RELEASE:+$RELEASE }: v2raya $V_SERVICE, v2raya-core $V_CORE, luci-app-v2raya-nextgen $V_LUCI"

# Check out the feed branch (or start it), replace this target, commit as one.
FEED="$WORK/feed"
if git_auth ls-remote --exit-code --heads "$URL" "$BRANCH" >/dev/null 2>&1; then
	git_auth clone --quiet --depth 1 --branch "$BRANCH" "$URL" "$FEED"
else
	mkdir "$FEED"
fi
if [ "$MODE" = apk ]; then
	TARGET="$FEED/$ARCH"
else
	TARGET="$FEED/opkg/$RELEASE/$ARCH"
fi
rm -rf "${TARGET:?}"
mkdir -p "$TARGET"
cp "$PKG"/* "$TARGET/"

# Rewrite the branch as one commit with the current packages only.
rm -rf "${FEED:?}/.git"
git -C "$FEED" init --quiet -b "$BRANCH"
git -C "$FEED" add -A
git -C "$FEED" -c user.name="feed-publisher" -c user.email="feed@users.noreply.github.com" \
	commit --quiet -m "feed: current packages"
git -C "$FEED" remote add origin "$URL"
git_auth -C "$FEED" push --quiet --force origin "$BRANCH"
echo "pushed $BRANCH: ${RELEASE:+opkg/$RELEASE/}$ARCH (one commit)"

# The apk installer pins these exact versions (see scripts/feed-setup.sh).
# opkg uses the index, not this file, and its version format differs
# (2.5.13-15 vs 2.5.13-r15), so never overwrite the apk pins from opkg.
if [ "$MODE" = apk ]; then
	{
		echo "v2raya=$V_SERVICE"
		echo "v2raya-core=$V_CORE"
		echo "luci-app-v2raya-nextgen=$V_LUCI"
	} > "$ROOT/feed/latest"
	echo "wrote feed/latest (commit it)"
fi
