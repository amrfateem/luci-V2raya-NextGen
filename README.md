# v2rayA NextGen for OpenWrt

Current upstream v2rayA (see [VERSION](VERSION)) packaged for OpenWrt
**23.05 and newer**, including OpenWrt **25.12** with the `apk` package manager.

> **AI-assisted project**
>
> This repository's packaging code, LuCI application, and CI were produced
> with AI assistance (DeepSeek V4.1 Flash) and are maintained by a human.
> Upstream v2rayA is a separate project by the v2rayA authors. Please read
> the code and test on your own device before relying on it.

---

## What this repository is

This is an **OpenWrt package feed**, not an OpenWrt firmware source tree. It
does not build OpenWrt images and it does not contain `target/`, `toolchain/`
or a firmware `.config`. The root-level directories are the packages:

| Directory | What it is |
| --- | --- |
| `v2raya/` | the service package (`Makefile`, init script, UCI config) |
| `v2raya-core/` | the matching `v2raya_core` binary package |
| `v2raya-geoip/` | the GeoIP data package |
| `v2raya-geosite/` | the GeoSite data package |
| `luci-app-v2raya/` | the LuCI app package |
| `scripts/` | optional helpers for building, installing and updating the packages |
| `.github/workflows/` | optional CI that builds and publishes package archives |

If you only need the package, copy the package directories into an existing
OpenWrt feed. The SDK helper under `scripts/` is only there to compile those
directories into `.ipk`/`.apk` files; it never compiles OpenWrt itself.

## Why this exists

The old `v2raya-openwrt` feed and the official OpenWrt `v2raya` package still
ship the 2.2.7.x generation. Since 2.5.x, v2rayA is a different application
layout:

* the service is `v2raya`;
* it requires a **matching** `v2raya_core` binary built from the same release;
* it needs `geoip.dat` and `geosite.dat` in `/usr/share/v2raya` at runtime; it
  downloads missing files on first start, or the optional data packages can
  provide them.

Mixing an old `v2raya` with a new core, or installing only one half, does not
work. This feed builds both halves from the same source tarball and installs
the rule data in the location the current release expects.

## What you get

| Package | Contents |
| --- | --- |
| `v2raya` | the service, `/etc/init.d/v2raya`, and `/etc/config/v2raya` |
| `v2raya-core` | the matching `v2raya_core` binary |
| `v2raya-geoip` | **optional** `geoip.dat` in `/usr/share/v2raya` |
| `v2raya-geosite` | **optional** `geosite.dat` in `/usr/share/v2raya` |
| `luci-app-v2raya` | LuCI overview, settings, and log pages |

`v2raya` does **not** depend on the data packages. If
`geoip.dat`/`geosite.dat` are missing, v2rayA downloads them on first start.
On an offline router, install `v2raya-geoip` and `v2raya-geosite` first.

The LuCI pages are at **Services → v2rayA**. They show the service
and core versions, let you start/stop/restart the service, expose the full
UCI configuration with tabs, and tail the log.

The packages use the canonical upstream names (`v2raya`, `v2raya-core`,
`luci-app-v2raya`). They upgrade the stock OpenWrt packages of the same name
in place. Previous builds of this repository used `-nextgen` suffixes; those
packages conflict with the canonical ones, so remove them first:

```sh
# OpenWrt 23.05 / 24.10
opkg remove luci-app-v2raya-nextgen v2raya-nextgen v2raya-core-nextgen

# OpenWrt 25.12
apk del luci-app-v2raya-nextgen v2raya-nextgen v2raya-core-nextgen
```

`scripts/install.sh` detects those packages and removes them for you.

## Compatibility

* OpenWrt **23.05**, **24.10**, and **25.12** (the CI builds all three).
* OpenWrt **25.12** uses `apk`; the older releases use `opkg`. The install
  script detects which one is present.
* The prebuilt release archives cover these package architectures:
  * `x86_64`
  * `aarch64_cortex-a53` (MediaTek Filogic, Qualcomm IPQ, many others)
  * `aarch64_cortex-a72` (Raspberry Pi 4 class)
  * `arm_cortex-a7_neon-vfpv4` (IPQ40xx and similar ARMv7 routers)
  * `mipsel_24kc` (MT7621 and many other MIPS routers)

  Other targets build from the same feed; see
  [Build from source](#build-from-source).

`v2raya` itself is pure Go. `v2raya_core` is also pure Go. The service only
needs CGO on `mips*` and `loong64`, where v2rayA's SQLite layer has no
pure-Go driver. The package handles that automatically.

## Xray-core, v2ray-core, and sing-box

v2rayA **2.5.x cannot use an external Xray-core or sing-box as its backend.**
Upstream replaced the old separate `xray-core` dependency with
`v2raya_core`, a fork of Xray-core, and the service generates configuration
that only that core understands. sing-box uses a different configuration
schema entirely.

This package therefore:

* installs only `v2raya_core`; it does not install, replace, or depend on
  `xray-core`, `v2ray-core`, or `sing-box`;
* detects an existing Xray/v2ray/sing-box installation and leaves it
  untouched, so no duplicate binary or init service is created;
* shows the detected binaries, packages, and proxy services on the LuCI
  **Overview** page;
* warns when another transparent-proxy stack (PassWall, SSR+, OpenClash,
  ShellCrash, mihomo, …) is enabled at boot, because two stacks adding
  nftables/iptables rules will conflict.

The Advanced “Core binary” setting is for `v2raya_core` only. Do not point it
at `/usr/bin/xray` or `/usr/bin/sing-box`; v2rayA will accept the path at
startup but the generated configuration will not run correctly.

| Backend | Usable as the v2rayA core? | What this package does |
| --- | --- | --- |
| `v2raya_core` | **Yes, required** | installs the matching version |
| Xray-core (`xray`) | No, removed from v2rayA 2.5.x | detects it, never replaces or starts it |
| v2ray-core (`v2ray`) | No, removed from v2rayA 2.5.x | detects it, never replaces or starts it |
| sing-box | No, different config format | detects it, never replaces or starts it |

The installer performs the same checks. Set `V2RAYA_NG_STRICT=1` to refuse
installation when another proxy service is enabled, or `V2RAYA_NG_DRY_RUN=1`
to only run the checks and print what would change.

If you installed the v2rayA **release binaries by hand**, the installer warns
that `/usr/bin/v2raya` and `/usr/bin/v2raya_core` will be replaced by the
packaged pair. Back up `/etc/v2raya` first; it contains your database and
settings.

## Install a prebuilt release

Download the archive for your OpenWrt release and architecture from the
[releases page](https://github.com/AmrFateem/luci-V2raya-NextGen/releases),
then:

```sh
mkdir -p /tmp/v2raya-ng
tar -xzf v2raya-nextgen-*-openwrt-25.12.6-*.tar.gz -C /tmp/v2raya-ng

# OpenWrt 25.12
apk add --allow-untrusted /tmp/v2raya-ng/*.apk

# OpenWrt 23.05 / 24.10
opkg install --force-reinstall /tmp/v2raya-ng/*.ipk
```

Or use the installer, which selects the right archive, verifies the
published checksum, and calls the right package manager:

```sh
uclient-fetch -O /tmp/install-v2raya-ng.sh \
  https://raw.githubusercontent.com/AmrFateem/luci-V2raya-NextGen/main/scripts/install.sh
sh /tmp/install-v2raya-ng.sh
```

`uclient-fetch` is part of the OpenWrt base system. If your build removed it,
use `curl -fsSL ... -o /tmp/install-v2raya-ng.sh` or
`wget -O /tmp/install-v2raya-ng.sh ...` instead.

To enable and start immediately:

```sh
V2RAYA_NG_START=1 sh /tmp/install-v2raya-ng.sh
```

To install the optional GeoIP/GeoSite packages too — useful for an offline
router — add:

```sh
V2RAYA_NG_GEODATA=1 sh /tmp/install-v2raya-ng.sh
```

Open `http://<router-ip>:2017`, create a password on the first visit, import
a subscription or share link, select a node, then enable the transparent
proxy mode you want.

## Migrating from the old feed

1. Keep `/etc/v2raya` and `/etc/config/v2raya`. They contain your database
   and settings; the new service migrates the old BoltDB database to SQLite
   on first start.
2. Install the new packages as above. The package names are identical to the
   stock feed (`v2raya`, `luci-app-v2raya`), so the package manager upgrades
   them in place and keeps `/etc/config/v2raya`.
3. If you previously installed a `-nextgen` build of this repository, remove
   those packages first (see [What you get](#what-you-get)).
4. Open the LuCI app, check the service address, and start it.

The UCI option names are the same as the old feed wherever possible
(`enabled`, `address`, `ipv6_support`, `nftables_support`, `log_level`, …), so
an existing configuration continues to work.

## Firewall and transparent proxy

`v2raya` depends on `nftables`, `kmod-nft-tproxy`, `ip-full`,
`kmod-tun`, and `ca-bundle`. That covers the default `nftables` path on
OpenWrt 22.03+ and TUN mode.

For the legacy `iptables` redirect path, install the extra packages yourself:

```sh
# OpenWrt 23.05 / 24.10
opkg update
opkg install iptables ip6tables iptables-mod-tproxy

# OpenWrt 25.12
apk add iptables ip6tables iptables-mod-tproxy
```

v2rayA creates and removes its own rules. Do not add the same redirect or
TPROXY rules to `/etc/config/firewall`; duplicated rules are a common source
of "it starts but nothing works" reports. Also make sure no other proxy app
(PassWall, SSR+, OpenClash, ShellCrash, mihomo, sing-box, …) is enabled at
the same time. The LuCI overview page lists detected services and warns when
another stack is enabled at boot.

For TUN mode, make sure `/dev/net/tun` exists and the `tun` kernel module is
loaded (`kmod-tun` is installed as a dependency).

## Memory and flash tuning

v2rayA 2.5.x is a Go service plus a full Xray-based core. On a 256 MB router
the pair normally uses about 55-60 MB of RSS, but a connection flood can push
it much higher. The package defaults are tuned for small routers:

| Option | Default | Why |
| --- | --- | --- |
| `gomemlimit` | `64MiB` | passes `GOMEMLIMIT` to both `v2raya` and `v2raya_core`; the Go runtime collects earlier instead of growing without bound |
| `gomaxprocs` | `2` | `GOMAXPROCS=2` uses fewer scheduler threads and per-P caches |
| `gogc` | `0` | keeps Go's default GC target; set `50` for less memory and more CPU |
| `nofile` | `16384` | bounds sockets and buffers if something on the LAN opens a connection flood |
| `log_level` | `warn` | reduces log writes, which matters on NAND flash |
| `log_max_days` | `1` | keeps the log file small |

Core dumps are disabled (`limits core="0 0"`), so a crash cannot fill the
overlay with a multi-hundred-megabyte core file.

Check the real numbers with `free -m` and the process RSS:

```sh
free -m
for p in $(pidof v2raya) $(pidof v2raya_core); do
    grep -E '^(Name|VmRSS|VmHWM|Threads):' /proc/$p/status
done
```

Do not trust the `Cached` line on the LuCI **Status → Overview** page: on
some LuCI/Argon combinations it displays an impossible value such as
`8723 MiB / 240 MiB`. The percentage is right and the absolute number is a
theme formatting bug; `free -m` is authoritative.

If memory is still tight, lower `gomemlimit` to `48MiB`, set `gogc` to `50`,
and reduce the number of subscriptions, nodes, and routing rules. Setting
`gomemlimit` too low causes GC thrashing and CPU spikes; raise it to `96MiB`
on a 512 MB router.

## Build from source

### As an OpenWrt feed

```sh
cd openwrt

echo "src-git v2raya_nextgen https://github.com/AmrFateem/luci-V2raya-NextGen.git" \
  >> feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install golang
./scripts/feeds install luci-base
# -f replaces the stock v2raya/luci-app-v2raya feed links with this feed
./scripts/feeds install -f -p v2raya_nextgen \
  v2raya v2raya-core v2raya-geoip v2raya-geosite \
  luci-app-v2raya

make menuconfig
# Network → Web Servers/Proxies → v2raya
# LuCI → Applications → luci-app-v2raya
make -j"$(nproc)"
```

The service module requires Go 1.26 and the core module requires Go 1.27.
The package Makefiles set `GOTOOLCHAIN=go1.27.3+auto`, so an older OpenWrt
host Go downloads the required toolchain from `proxy.golang.org` during the
build. The build host therefore needs network access, or a pre-populated Go
module cache.

### One target with the SDK

The helper downloads the official SDK, adds this checkout as a feed, installs
the Go toolchain, builds all packages, and writes an archive under `dist/`:

```sh
sh scripts/build-packages.sh 25.12.6 x86/64
sh scripts/build-packages.sh 24.10.8 ramips/mt7621
```

The build tree goes to `${V2RAYA_NG_BUILD_DIR:-/tmp/v2raya-nextgen-build}`.
Keep it outside the checkout: the SDK adds the checkout as a feed, and an SDK
directory inside the feed root makes the feed scanner walk into itself.

## Updating

`scripts/update-version.sh` refreshes:

* the v2rayA service/core version and source hash,
* the `web.tar.gz` hash,
* the LuCI app version,
* the Go toolchain (from the upstream `go.mod` files),
* the v2fly GeoIP/GeoSite versions and hashes.

The `Update upstream versions` GitHub Action runs it daily and opens a pull
request when something changed. Merging that PR is the normal update path;
tag a release afterwards to build and publish the binaries.

To make a release:

```sh
git tag v2.5.13-r7
git push origin v2.5.13-r7
```

The `Release packages` workflow builds OpenWrt 23.05/24.10/25.12 for the
supported target matrix, writes one archive per architecture, publishes a
`SHA256SUMS` file, and attaches everything to the GitHub release.

## Verification and limitations

* The 25.12.6 `x86_64` package set was built in the official SDK and its
  binaries were built from the tagged v2rayA 2.5.13 source with the matching
  `v2raya_core`. The pair was started on loopback and served the embedded web
  UI (`scripts/smoke-test.sh`).
* The 25.12.6 `ipq40xx/generic` ARMv7 package set was built in the official
  SDK and installed on a router. The service, core, DNS, LAN transparent
  proxy, and LuCI view were verified against a real WAN connection.
* The 2.5.13 `v2raya_core` was also cross-compiled for `linux/mips` and
  `linux/mipsle` with CGO disabled, confirming that the MIPS release matrix
  can build the core.
* It has **not** been tested on every router model. Transparent proxy and TUN
  behavior depend on the target kernel, firewall backend, and available
  kernel modules.
* MIPS routers with very small flash cannot fit the core plus optional GeoIP
  data. The two Go binaries alone are about 64 MB installed; the full GeoIP
  database adds another 23 MB, so plan for roughly 128 MB of free flash if
  you install the data packages. Without them, about 64 MB is still needed
  for the binaries.
* The web UI listens on `0.0.0.0:2017` by default, like the upstream package.
  Set a password immediately, or bind it to `127.0.0.1:2017` and use an SSH
  tunnel / reverse proxy.
* This is an independent packaging project, not an official v2rayA release.

## Troubleshooting

* **Web UI does not open:** check `logread | grep v2raya` and
  `/var/log/v2raya/v2raya.log`. Confirm the service is enabled and running
  with `ubus call service list '{"name":"v2raya"}'`.
* **LAN clients get “server not found” / no DNS:** v2rayA 2.5.x defaults to
  DNS hijacking and sends client DNS through the proxy. If your node does not
  carry UDP (many vless/ws nodes do not), DNS breaks. Set **Settings → DNS →
  DNS mode → Off** in the v2rayA web UI, or leave `dnsMode` off. Release r4
  and newer default it to off for fresh databases.
* **LAN clients are not proxied:** remove `br-*` from **Settings →
  Transparent Proxy → Excluded Interface Prefixes**. OpenWrt’s LAN is
  `br-lan`; excluding `br-*` bypasses every LAN client. Release r3 and newer
  remove it from the default.
* **Pages hang, but `curl -4` works:** browsers use QUIC/HTTP3 (UDP 443),
  which many proxy nodes do not carry. Disable HTTP/3 in the browser, or
  block UDP 443 from the LAN so browsers fall back to TCP.
* **The service is running but the proxy is not connected:** starting the
  procd service is not the same as connecting v2rayA. Open the v2rayA web UI
  and press **Connect/Start** there. The LuCI page only controls the service.
* **LuCI says stopped but the proxy still works:** the LuCI **Stop** button
  stops the system service. The v2rayA web UI **Stop** button stops only
  `v2raya_core`; the web service stays up by design. If the service is
  stopped and `v2raya_core` still appears in `ps`, the core is stuck, usually
  on flash I/O. Check `dmesg` for SPI/UBI errors and reboot if it is stuck.
* **The LuCI memory page shows an impossible `Cached` value:** some
  LuCI/Argon versions print kilobytes as if they were MiB. Use `free -m`
  instead; the percentage is correct.
* **Forgot the web password:** stop the service, reset the accounts, and
  start it again:

  ```sh
  /etc/init.d/v2raya stop
  /usr/bin/v2raya --reset-password --config /etc/v2raya
  /etc/init.d/v2raya start
  ```

* **Core fails to start on a slow router:** raise `core_startup_timeout` in
  the settings (or `uci set v2raya.config.core_startup_timeout='30'`).
* **First start is slow or fails with a download error:** v2rayA downloads
  missing `geoip.dat`/`geosite.dat` on first start. On an offline router,
  install `v2raya-geoip` and `v2raya-geosite` first.
* **Transparent proxy starts but traffic is not redirected:** check that
  `nft`/`kmod-nft-tproxy` are installed, that no duplicate rules were added
  to `/etc/config/firewall`, and that the upstream gateway/DNS is reachable
  from the router.
* **Database migration from the old feed:** the first start of 2.5.x imports
  `bolt.db` into `v2raya.db`. Keep a backup of `/etc/v2raya` before upgrading
  a production router.

## AI disclosure

This repository is **AI-assisted**. The package Makefiles, init script, LuCI
views, CI workflows, and documentation were drafted with DeepSeek V4.1 Flash
and are reviewed and maintained by a human. AI output can be wrong; the
maintainer is responsible for the published result.

If you redistribute this project, keep this disclosure with it. Do not
describe it as an official v2rayA build.

If you submit this packaging to OpenWrt, read [UPSTREAM.md](UPSTREAM.md)
first. The OpenWrt packages feed requires LLM usage to be disclosed in the
pull request or commit messages, and it closes PRs it believes were opened
autonomously. A human must open the PR and answer the review.

## Credits and licenses

* Upstream application: [v2rayA/v2rayA](https://github.com/v2rayA/v2rayA),
  AGPL-3.0-only. The `v2raya_core` component is MPL-2.0.
* Packaging structure adapted from the
  [v2raya-openwrt feed](https://github.com/v2rayA/v2raya-openwrt) and the
  [OpenWrt packages feed](https://github.com/openwrt/packages), originally by
  Tianling Shen and contributors.
* GeoIP data: [v2fly/geoip](https://github.com/v2fly/geoip), CC-BY-SA-4.0.
* GeoSite data: [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community),
  MIT.
* The packaging in this repository is GPL-3.0-only; the LuCI application is
  Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for the upstream
  binary licenses and source locations.
