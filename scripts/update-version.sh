#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Refresh the package definitions from the latest upstream releases.
#
# Updates:
#   - v2rayA service + core versions, source hash and web bundle hash
#   - the LuCI app version
#   - the Go toolchain used to build both modules
#   - the v2fly GeoIP and GeoSite databases
#
# Requires: curl, jq, sha256sum, awk, sed.  Run from a clean checkout; the
# script only edits tracked files, so `git diff` is the review.

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
API="https://api.github.com/repos"
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t v2raya-ng)
trap 'rm -rf "$TMP"' EXIT

need() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "Missing required command: $1" >&2
		exit 1
	}
}

need curl
need jq
need sha256sum

# Replace a line whose content starts with exactly $2, preserving the rest of
# the file.  Using awk avoids sed regex escaping for keys like "?=".
set_line() {
	file="$1"
	key="$2"
	value="$3"
	tmp="$file.tmp.$$"
	awk -v key="$key" -v value="$value" '
		index($0, key) == 1 { print key value; next }
		{ print }
	' "$file" >"$tmp"
	mv "$tmp" "$file"
}

get_line_value() {
	file="$1"
	key="$2"
	awk -v key="$key" 'index($0, key) == 1 { sub("^" key, ""); print; exit }' "$file"
}

download_hash() {
	url="$1"
	out="$2"
	curl --http1.1 -fL --retry 5 --retry-all-errors --retry-delay 2 \
		--silent --show-error -o "$out" "$url"
	sha256sum "$out" | awk '{ print $1 }'
}

# Use the workflow token when available so shared runner IPs do not hit the
# unauthenticated GitHub API rate limit.
api_get() {
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$1"
	else
		curl -fsSL "$1"
	fi
}

update_v2raya() {
	echo "==> Checking v2rayA"
	release=$(api_get "$API/v2rayA/v2rayA/releases/latest")
	tag=$(printf '%s' "$release" | jq -r '.tag_name')
	version=${tag#v}

	[ -n "$version" ] && [ "$version" != "null" ] || {
		echo "Could not determine the latest v2rayA version" >&2
		exit 1
	}

	current=$(get_line_value "$ROOT/v2raya/Makefile" "PKG_VERSION:=")
	if [ "$current" = "$version" ]; then
		echo "    v2rayA is already at $version"
		return
	fi

	echo "    updating v2rayA $current -> $version"
	curl --http1.1 -fL --retry 5 --retry-all-errors --retry-delay 2 --silent --show-error \
		-o "$TMP/source.tar.gz" "https://codeload.github.com/v2rayA/v2rayA/tar.gz/v${version}"
	source_hash=$(sha256sum "$TMP/source.tar.gz" | awk '{ print $1 }')
	web_hash=$(download_hash \
		"https://github.com/v2rayA/v2rayA/releases/download/v${version}/web.tar.gz" \
		"$TMP/web.tar.gz")

	# The LuCI app has a date-based version of its own; see its Makefile.
	for file in \
		"$ROOT/v2raya/Makefile" \
		"$ROOT/v2raya-core/Makefile"; do
		set_line "$file" "PKG_VERSION:=" "$version"
		set_line "$file" "PKG_RELEASE:=" "1"
	done

	set_line "$ROOT/v2raya/Makefile" "PKG_HASH:=" "$source_hash"
	set_line "$ROOT/v2raya-core/Makefile" "PKG_HASH:=" "$source_hash"
	set_line "$ROOT/v2raya/Makefile" "WEB_HASH:=" "$web_hash"

	printf '%s\n' "$version" >"$ROOT/VERSION"
}

update_go_toolchain() {
	echo "==> Checking the Go toolchain"

	version=$(get_line_value "$ROOT/v2raya/Makefile" "PKG_VERSION:=")

	curl --http1.1 -fsSL --retry 3 --retry-all-errors --silent --show-error \
		-o "$TMP/service.mod" "https://raw.githubusercontent.com/v2rayA/v2rayA/v${version}/service/go.mod"
	curl --http1.1 -fsSL --retry 3 --retry-all-errors --silent --show-error \
		-o "$TMP/core.mod" "https://raw.githubusercontent.com/v2rayA/v2rayA/v${version}/core/go.mod"

	service_go=$(awk '/^go /{ print $2; exit }' "$TMP/service.mod")
	core_go=$(awk '/^go /{ print $2; exit }' "$TMP/core.mod")

	required=$(printf '%s\n%s\n' "$service_go" "$core_go" | sort -V | tail -n 1)
	minor=${required%.*}

	toolchain=$(curl --http1.1 -fsSL --retry 3 --retry-all-errors --silent --show-error \
		"https://go.dev/dl/?mode=json" |
		jq -r --arg prefix "go${minor}." \
			'[ .[] | select(.stable == true) | .version | select(startswith($prefix)) ][0] // empty')

	if [ -z "$toolchain" ]; then
		echo "    could not resolve a Go ${minor}.x toolchain; keeping the current value" >&2
		return
	fi

	echo "    required Go $required, using $toolchain"
	set_line "$ROOT/v2raya/Makefile" "V2RAYA_GO_TOOLCHAIN?=" "${toolchain}+auto"
	set_line "$ROOT/v2raya-core/Makefile" "V2RAYA_GO_TOOLCHAIN?=" "${toolchain}+auto"
}

update_geodata() {
	name="$1"
	repo="$2"
	makefile="$3"
	hash_key="$4"
	hash_asset="$5"

	echo "==> Checking $name"
	release=$(api_get "$API/$repo/releases/latest")
	tag=$(printf '%s' "$release" | jq -r '.tag_name')
	[ -n "$tag" ] && [ "$tag" != "null" ] || {
		echo "Could not determine the latest $name version" >&2
		return
	}

	current=$(get_line_value "$makefile" "PKG_VERSION:=")
	if [ "$current" = "$tag" ]; then
		echo "    $name is already at $tag"
		return
	fi

	hash=$(curl --http1.1 -fsSL --retry 5 --retry-all-errors --silent --show-error \
		"https://github.com/$repo/releases/download/$tag/$hash_asset" | awk '{ print $1 }')

	[ -n "$hash" ] || {
		echo "Could not read the $name checksum" >&2
		return
	}

	echo "    updating $name $current -> $tag"
	set_line "$makefile" "PKG_VERSION:=" "$tag"
	set_line "$makefile" "PKG_RELEASE:=" "1"
	set_line "$makefile" "$hash_key" "$hash"
}

update_feed_pins() {
	echo "==> Updating the installer pins"
	service_version=$(get_line_value "$ROOT/v2raya/Makefile" "PKG_VERSION:=")
	service_release=$(get_line_value "$ROOT/v2raya/Makefile" "PKG_RELEASE:=")
	core_version=$(get_line_value "$ROOT/v2raya-core/Makefile" "PKG_VERSION:=")
	core_release=$(get_line_value "$ROOT/v2raya-core/Makefile" "PKG_RELEASE:=")
	app_version=$(get_line_value "$ROOT/luci-app-v2raya-nextgen/Makefile" "PKG_VERSION:=")
	app_release=$(get_line_value "$ROOT/luci-app-v2raya-nextgen/Makefile" "PKG_RELEASE:=")
	pins="$ROOT/feed/latest"
	tmp="$pins.tmp.$$"
	{
		printf 'v2raya=%s-r%s\n' "$service_version" "$service_release"
		printf 'v2raya-core=%s-r%s\n' "$core_version" "$core_release"
		printf 'luci-app-v2raya-nextgen=%s-r%s\n' "$app_version" "$app_release"
	} >"$tmp"
	if [ -f "$pins" ] && cmp -s "$tmp" "$pins"; then
		rm -f "$tmp"
		echo "    feed/latest is current"
	else
		mv "$tmp" "$pins"
		echo "    wrote feed/latest"
	fi
}

update_v2raya
update_go_toolchain
update_geodata "GeoIP" "v2fly/geoip" "$ROOT/v2raya-geoip/Makefile" \
	"GEOIP_HASH:=" "geoip.dat.sha256sum"
update_geodata "GeoSite" "v2fly/domain-list-community" "$ROOT/v2raya-geosite/Makefile" \
	"GEOSITE_HASH:=" "dlc.dat.sha256sum"
update_feed_pins

echo
echo "==> Current versions"
echo "    v2rayA:  $(get_line_value "$ROOT/v2raya/Makefile" "PKG_VERSION:=")"
echo "    GeoIP:   $(get_line_value "$ROOT/v2raya-geoip/Makefile" "PKG_VERSION:=")"
echo "    GeoSite: $(get_line_value "$ROOT/v2raya-geosite/Makefile" "PKG_VERSION:=")"
echo
echo "Review with: git diff"
