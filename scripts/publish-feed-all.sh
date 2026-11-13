#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Publish every architecture from a directory of release archives to the
# `feed` branch as one commit.
#
# Usage:
#   sh scripts/publish-feed-all.sh <dist-dir>
#
# <dist-dir> may be flat or hold one subdirectory per downloaded artifact. It
# must contain the .tar.gz archives produced by scripts/build-packages.sh.
#
# Environment:
#   V2RAYA_FEED_KEY_FILE  private key used to sign the apk indexes
#   V2RAYA_FEED_KEY       accepted as an alias for V2RAYA_FEED_KEY_FILE
#   V2RAYA_OPKG_KEY_FILE  usign private key used to sign the opkg indexes
#   V2RAYA_OPKG_KEY       accepted as an alias for V2RAYA_OPKG_KEY_FILE
#   APK_BIN               apk binary to use (default: apk from PATH)
#   USIGN_BIN             usign binary to use (default: usign from PATH)
#   GITHUB_TOKEN          token with contents:write
#   GITHUB_REPOSITORY     owner/repo (default: AmrFateem/luci-V2raya-NextGen)
#   FEED_EXPECT_APK       expected apk architectures (default: 5; 0 disables)
#   FEED_EXPECT_OPKG      expected opkg feeds (default: 10; 0 disables)
#   FEED_SKIP_PIN_CHECK   set to 1 to allow artifacts that differ from feed/latest
#   FEED_DRY_RUN          set to 1 to stage and index without pushing

set -eu

REPO="${GITHUB_REPOSITORY:-AmrFateem/luci-V2raya-NextGen}"
BRANCH="feed"
DIST="${1:-}"

die() {
	echo "Error: $*" >&2
	exit 1
}

[ -n "$DIST" ] && [ -d "$DIST" ] ||
	die "usage: sh scripts/publish-feed-all.sh <dist-dir>"

APK_KEY="${V2RAYA_FEED_KEY_FILE:-${V2RAYA_FEED_KEY:-}}"
OPKG_KEY="${V2RAYA_OPKG_KEY_FILE:-${V2RAYA_OPKG_KEY:-}}"
APK_BIN="${APK_BIN:-apk}"
USIGN_BIN="${USIGN_BIN:-usign}"

if [ "${FEED_DRY_RUN:-0}" != "1" ]; then
	TOKEN="${GITHUB_TOKEN:?set GITHUB_TOKEN to a token with repo access}"
fi

for tool in find git tar gzip sha256sum stat cut sort; do
	command -v "$tool" >/dev/null 2>&1 || die "missing $tool"
done

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d 2>/dev/null || mktemp -d -t v2raya-feed-all)
trap 'rm -rf "$WORK"' EXIT

STAGING="$WORK/staging"
mkdir -p "$STAGING/apk" "$STAGING/opkg"
find "$DIST" -type f -name '*.tar.gz' -print | sort >"$WORK/archives"
[ -s "$WORK/archives" ] || die "no .tar.gz archives under $DIST"

one_pkg() {
	dir="$1"
	pattern="$2"
	name="$3"
	count=$(find "$dir" -maxdepth 1 -type f -name "$pattern" | wc -l)
	[ "$count" -eq 1 ] ||
		die "$dir must hold exactly one $name package (found $count)"
}

while IFS= read -r archive; do
	name=$(basename "$archive")
	release=$(printf '%s\n' "$name" |
		sed -n 's/.*openwrt-\([0-9][0-9.]*\)-[^/]*\.tar\.gz$/\1/p')
	arch=$(printf '%s\n' "$name" |
		sed -n 's/.*openwrt-[0-9][0-9.]*-\([^/]*\)\.tar\.gz$/\1/p')
	[ -n "$release" ] && [ -n "$arch" ] ||
		die "cannot parse the OpenWrt release and architecture from $name"

	extract="$WORK/extract/$release-$arch"
	rm -rf "$extract"
	mkdir -p "$extract"
	tar -xzf "$archive" -C "$extract"

	if find "$extract" -maxdepth 1 -type f -name 'v2raya-[0-9]*.apk' | grep -q .; then
		mode=apk
		one_pkg "$extract" 'v2raya-[0-9]*.apk' v2raya
		one_pkg "$extract" 'v2raya-core-[0-9]*.apk' v2raya-core
		one_pkg "$extract" 'luci-app-v2raya-nextgen-[0-9]*.apk' luci-app-v2raya-nextgen
		dest="$STAGING/apk/$arch"
	else
		mode=opkg
		one_pkg "$extract" 'v2raya_[0-9]*.ipk' v2raya
		one_pkg "$extract" 'v2raya-core_[0-9]*.ipk' v2raya-core
		one_pkg "$extract" 'luci-app-v2raya-nextgen_[0-9]*.ipk' luci-app-v2raya-nextgen
		major=$(printf '%s' "$release" | cut -d. -f1-2)
		dest="$STAGING/opkg/$major/$arch"
	fi

	[ ! -e "$dest" ] || die "duplicate $release $arch archives in $DIST"
	mkdir -p "$dest"
	if [ "$mode" = apk ]; then
		cp "$extract"/*.apk "$dest/"
	else
		cp "$extract"/*.ipk "$dest/"
	fi
	echo "staged $release $arch ($mode)"
done <"$WORK/archives"

apk_dirs=$(find "$STAGING/apk" -mindepth 1 -maxdepth 1 -type d | wc -l)
opkg_dirs=$(find "$STAGING/opkg" -mindepth 2 -maxdepth 2 -type d | wc -l)

expect_apk="${FEED_EXPECT_APK:-5}"
expect_opkg="${FEED_EXPECT_OPKG:-10}"
if [ "$expect_apk" -ne 0 ] && [ "$apk_dirs" -ne "$expect_apk" ]; then
	die "expected $expect_apk apk architectures, found $apk_dirs"
fi
if [ "$expect_opkg" -ne 0 ] && [ "$opkg_dirs" -ne "$expect_opkg" ]; then
	die "expected $expect_opkg opkg feeds, found $opkg_dirs"
fi

if [ "$apk_dirs" -gt 0 ]; then
	[ -n "$APK_KEY" ] && [ -f "$APK_KEY" ] ||
		die "set V2RAYA_FEED_KEY_FILE to the apk signing key"
	if [ -x "$APK_BIN" ]; then
		:
	elif command -v "$APK_BIN" >/dev/null 2>&1; then
		:
	else
		die "cannot run apk (set APK_BIN)"
	fi
fi

if [ "$opkg_dirs" -gt 0 ]; then
	[ -n "$OPKG_KEY" ] && [ -f "$OPKG_KEY" ] ||
		die "set V2RAYA_OPKG_KEY_FILE to the opkg usign key"
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
	echo "opkg signing key: $opkg_pub_fp"
fi

for dir in "$STAGING"/apk/*; do
	[ -d "$dir" ] || continue
	"$APK_BIN" mkndx --allow-untrusted --sign-key "$APK_KEY" \
		-o "$dir/packages.adb" "$dir"/*.apk
	echo "indexed apk $(basename "$dir")"
done

for rel_dir in "$STAGING"/opkg/*; do
	[ -d "$rel_dir" ] || continue
	for dir in "$rel_dir"/*; do
		[ -d "$dir" ] || continue
		(
			cd "$dir"
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
			done >Packages
			"$USIGN_BIN" -S -m Packages -s "$OPKG_KEY" -x Packages.sig
			gzip -9c Packages >Packages.gz
		)
		echo "indexed opkg $(basename "$rel_dir")/$(basename "$dir")"
	done
done

first_apk=$(find "$STAGING/apk" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)
version_of() {
	dir="$1"
	prefix="$2"
	file=$(find "$dir" -maxdepth 1 -type f -name "$prefix-[0-9]*.apk" | head -n 1)
	base=$(basename "$file" .apk)
	printf '%s\n' "${base#"$prefix"-}"
}
if [ -n "$first_apk" ]; then
	V_SERVICE=$(version_of "$first_apk" v2raya)
	V_CORE=$(version_of "$first_apk" v2raya-core)
	V_LUCI=$(version_of "$first_apk" luci-app-v2raya-nextgen)
else
	V_SERVICE=unknown
	V_CORE=unknown
	V_LUCI=unknown
fi
echo "versions: $V_SERVICE / $V_CORE / $V_LUCI"

PINS="$ROOT/feed/latest"
if [ "${FEED_SKIP_PIN_CHECK:-0}" != "1" ] &&
	[ -f "$PINS" ] && [ "$V_SERVICE" != "unknown" ]; then
	for pair in \
		"v2raya:$V_SERVICE" \
		"v2raya-core:$V_CORE" \
		"luci-app-v2raya-nextgen:$V_LUCI"; do
		pin_name=${pair%%:*}
		pin_want=${pair#*:}
		pin_got=$(awk -F= -v name="$pin_name" '$1 == name { print $2 }' "$PINS")
		[ "$pin_got" = "$pin_want" ] ||
			die "feed/latest pins $pin_name $pin_got but the artifacts are $pin_want; run scripts/update-version.sh and commit first"
	done
fi

FEED="$WORK/feed"
mkdir -p "$FEED"
# apk feeds live at the branch root (<arch>/packages.adb), matching the URLs
# already configured on routers. opkg feeds live under opkg/<release>/<arch>.
for src in "$STAGING"/apk/*; do
	[ -d "$src" ] || continue
	cp -a "$src" "$FEED/"
done
if [ -d "$STAGING/opkg" ]; then
	cp -a "$STAGING/opkg" "$FEED/"
fi
find "$FEED" -type d -empty -delete

if [ "${FEED_DRY_RUN:-0}" = "1" ]; then
	echo "dry run: staged feed at $FEED"
	echo "apk feeds: $apk_dirs, opkg feeds: $opkg_dirs"
	exit 0
fi

git -C "$FEED" init --quiet -b "$BRANCH"
git -C "$FEED" add -A
git -C "$FEED" -c user.name="feed-publisher" \
	-c user.email="feed@users.noreply.github.com" \
	commit --quiet -m "feed: v2raya $V_SERVICE ($apk_dirs apk, $opkg_dirs opkg)"
git -C "$FEED" remote add origin "https://github.com/$REPO.git"

AUTH="Authorization: Basic $(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')"
git -C "$FEED" -c "http.extraHeader=$AUTH" \
	push --quiet --force origin "$BRANCH"
echo "pushed $BRANCH: $apk_dirs apk architectures, $opkg_dirs opkg feeds (one commit)"
