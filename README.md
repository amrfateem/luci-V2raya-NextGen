# v2rayA for OpenWrt

v2rayA 2.5.x and its LuCI app for OpenWrt 23.05, 24.10 and 25.12.

## Install

SSH to the router as root and run:

```sh
wget -qO- https://raw.githubusercontent.com/AmrFateem/luci-V2raya-NextGen/main/scripts/feed-setup.sh | sh
```

The installer detects apk (25.12) or opkg (23.05 and 24.10), adds the feed, and installs the current versions.

Then open LuCI → Services → v2rayA, or `http://<router>:2017`.

To update later, run the same command again. It changes only `v2raya`, `v2raya-core` and `luci-app-v2raya-nextgen`.

## Add the feed manually

The installer does this for you. If you prefer to add the repository yourself,
use the URL for your OpenWrt release and architecture.

**apk (OpenWrt 25.12+)**

```sh
ARCH=$(sed -n "s/^DISTRIB_ARCH='\(.*\)'/\1/p" /etc/openwrt_release)
mkdir -p /etc/apk/keys /etc/apk/repositories.d
wget -qO /etc/apk/keys/v2raya-feed.pem \
  https://raw.githubusercontent.com/AmrFateem/luci-V2raya-NextGen/main/feed/public-key.pem
echo "https://raw.githubusercontent.com/AmrFateem/luci-V2raya-NextGen/feed/$ARCH/packages.adb" \
  > /etc/apk/repositories.d/v2raya.list
apk update
apk add v2raya v2raya-core luci-app-v2raya-nextgen
```

**opkg (OpenWrt 23.05 and 24.10)**

```sh
RELEASE=$(sed -n "s/^DISTRIB_RELEASE='\(.*\)'/\1/p" /etc/openwrt_release)
ARCH=$(sed -n "s/^DISTRIB_ARCH='\(.*\)'/\1/p" /etc/openwrt_release)
MINOR=${RELEASE%.*}
touch /etc/opkg/customfeeds.conf
sed -i '/v2raya/d' /etc/opkg/customfeeds.conf
echo "src/gz v2raya https://raw.githubusercontent.com/AmrFateem/luci-V2raya-NextGen/feed/opkg/$MINOR/$ARCH" \
  >> /etc/opkg/customfeeds.conf
wget -qO /tmp/v2raya-opkg.pub \
  https://raw.githubusercontent.com/AmrFateem/luci-V2raya-NextGen/main/feed/opkg.pub
opkg-key add /tmp/v2raya-opkg.pub
rm -f /tmp/v2raya-opkg.pub
opkg update
opkg install v2raya v2raya-core luci-app-v2raya-nextgen
```

The served architectures are `aarch64_cortex-a53`, `aarch64_cortex-a72`,
`arm_cortex-a7_neon-vfpv4`, `mipsel_24kc`, and `x86_64`. The `feed` branch is
replaced with the current packages on every release, so these URLs stay the
same. The apk index and the opkg indexes are signed; the public keys above are
required. The opkg key fingerprint is `955262cbfde16422`; `feed-setup.sh`
checks it before installing. If the old `luci-app-v2raya` package is installed,
remove it first because it conflicts with `luci-app-v2raya-nextgen`.

If `apk update` reports `wget: exited with error 8` or `unexpected end of file`
just after a release, clear the cached index and retry:

```sh
rm -rf /var/cache/apk/*
apk update
```

## Updates

`update.yml` checks upstream every day. When v2rayA publishes a new
release it refreshes the versions and hashes, amends the single `main`
commit, tags `v<version>`, and dispatches `release.yml`. That workflow builds
all 15 targets, then `scripts/publish-feed-all.sh` replaces the `feed` branch
with one commit holding every apk and opkg feed.

To check immediately, run **Actions → Update upstream versions → Run
workflow**. A `repository_dispatch` event named `v2raya-update` triggers the
same check. A GeoIP/GeoSite refresh alone only amends `main`; it does not
start a package build.

The apk indexes are signed with the `V2RAYA_FEED_KEY` Actions secret and the
opkg indexes with `V2RAYA_OPKG_KEY`. The private keys are not in the
repository.

## Set up

- Transparent proxy: `pac` mode with `routingA`.
- Keep QUIC sniffing on: `http,tls,quic`.
- Routing rules, one per line:

  ```
  default: proxy
  domain(domain:example.com)->direct
  ip(geoip:private)->direct
  ```

- Firewall: `fw4` must load and keep WAN masquerade:

  ```sh
  nft list table inet fw4 | grep masquerade
  fw4 print
  ```

## What it installs

- `v2raya`: the service and web UI
- `v2raya-core`: the core that v2rayA runs
- `luci-app-v2raya-nextgen`: your LuCI pages for status, settings and logs

The service keeps the name `v2raya` and the config `/etc/config/v2raya`, so existing settings and the database survive the app rename.

## Build

The repository contains only the packaging. v2rayA and its web UI are fetched at build time and pinned by hash.

```sh
# apk (25.12)
sh scripts/build-packages.sh 25.12.6 ipq40xx/generic

# opkg (24.10 and 23.05)
sh scripts/build-packages.sh 24.10.8 ipq40xx/generic
sh scripts/build-packages.sh 23.05.6 ipq40xx/generic
```

Output goes to `dist/`.

## Publish (maintainers)

The feed lives on the `feed` branch, as one commit with the current packages only. It is served by `raw.githubusercontent.com`. The signing keys are kept outside the repository. `release.yml` publishes it automatically on a tag or when `publish_feed` is selected.

```sh
# All architectures from downloaded release archives, in one commit.
V2RAYA_FEED_KEY_FILE=/path/to/feed.pem \
V2RAYA_OPKG_KEY_FILE=/path/to/opkg.key \
GITHUB_TOKEN=... sh scripts/publish-feed-all.sh <dist-dir>

# One architecture, for a manual fix.
V2RAYA_FEED_KEY_FILE=/path/to/feed.pem GITHUB_TOKEN=... \
  sh scripts/publish-feed.sh <apk-dir> arm_cortex-a7_neon-vfpv4
V2RAYA_OPKG_KEY_FILE=/path/to/opkg.key GITHUB_TOKEN=... \
  sh scripts/publish-feed.sh <ipk-dir> arm_cortex-a7_neon-vfpv4 24.10
```

`publish-feed-all.sh` expects 5 apk and 10 opkg inputs by default, checks that
`feed/opkg.pub` matches the opkg signing key, and refuses to publish artifacts
whose versions do not match `feed/latest`. Set
`FEED_EXPECT_APK=0 FEED_EXPECT_OPKG=0` for a partial publish, or
`FEED_SKIP_PIN_CHECK=1` to bypass the pin check.

## Test

- `scripts/validate.sh`: syntax and lint checks.
- `tests/router-test.sh`: run on the router as root. It checks the installed packages, the firewall, a stop and start cycle, and DNS.
- `tests/lan-client-test.ps1`: run from a Windows PC on the LAN.

## Known issues

See [KNOWN-ISSUES.md](KNOWN-ISSUES.md).

## License and source

Unofficial packaging. Not affiliated with the v2rayA authors.

- v2rayA 2.5.15: AGPL-3.0-only. Source: <https://github.com/v2rayA/v2rayA/tree/v2.5.15> plus the patches in `v2raya/patches/`.
- v2raya-core 2.5.15: MPL-2.0. Source: `core/` in the same tag.
- LuCI app: Apache-2.0.
- Packaging, init scripts, tests: GPL-3.0-only.
- GeoIP (optional): CC-BY-SA-4.0. GeoSite (optional): MIT.

Full texts are in [LICENSES/](LICENSES/). [THIRD-PARTY.md](THIRD-PARTY.md) lists versions, upstream sources, and changes.

The complete source for the binaries is this repository at the release commit plus the upstream v2rayA v2.5.15 tag. The upstream source is pinned by hash in the Makefiles. If you use the v2rayA web UI over a network, that source is the offer required by AGPL section 13.

Packaging and documentation were drafted with AI assistance and reviewed by the maintainer.
