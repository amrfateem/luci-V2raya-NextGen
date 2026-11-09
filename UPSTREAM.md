# Submitting this packaging to OpenWrt

This is a checklist for preparing the upstream pull requests. It is based on:

- <https://github.com/openwrt/packages/blob/master/CONTRIBUTING.md>
- <https://github.com/openwrt/packages/blob/master/.github/llm-review-rules.md>
- <https://github.com/openwrt/luci/blob/master/CONTRIBUTING.md>
- <https://openwrt.org/docs/guide-developer/packages>

The wiki page is behind Anubis bot protection, so the text above was verified
from the official repository files, which are the same rules the formality bot
and CI use.

## Short answer

Yes, you are making packages. But an upstream submission is **not** this
repository as-is:

- `openwrt/packages` gets the service, core and data packages.
- `openwrt/luci` gets the LuCI app.
- The local package names already match the canonical upstream names
  (`v2raya`, `v2raya-core`, `luci-app-v2raya`); only the paths and the
  build-tree includes need adjusting.
- The AI usage must be disclosed in the PR and/or commit messages.
- The PR must be opened by you, with a real name, real email and
  `Signed-off-by`. Do not use an autonomous agent to create or comment on the
  PR; the packages project explicitly closes PRs it believes were created
  autonomously.

## Two pull requests, not one

### 1. `openwrt/packages`

Target paths:

| Local directory | Upstream path | Package name |
| --- | --- | --- |
| `v2raya/` | `net/v2raya/` | `v2raya` |
| `v2raya-core/` | `net/v2raya-core/` | `v2raya-core` |
| `v2raya-geoip/` | `net/v2raya-geoip/` | `v2raya-geoip` |
| `v2raya-geosite/` | `net/v2raya-geosite/` | `v2raya-geosite` |

Notes:

- `net/v2raya` already exists in the feed and is maintained by Tianling Shen.
  This is an update/replacement of that package, not a new package. Coordinate
  with the existing maintainer before opening the PR. Do not remove their
  maintainer entry without consent; add yourself alongside them.
- `v2raya-core` is a new package. It builds the matching `v2raya_core` binary
  from the same upstream source tarball.
- `v2raya-geoip` and `v2raya-geosite` are new data packages. The official feed
  currently has no `v2fly-geodata` package, so either add these or make
  `v2raya` use the data from `v2ray-extra` (not recommended: it pulls the
  separate v2ray-core package just for data).
- The local LuCI app is not part of the `packages` PR.
- Do not submit `scripts/`, `.github/`, `README.md`, `NOTICE`, `SECURITY.md` or
  the top-level repository metadata with the package PR. Only the package
  directories and their `test.sh` files belong there.

Suggested commits:

```text
v2raya: update to 2.5.13
v2raya-core: add package
v2raya-geoip: add package
v2raya-geosite: add package
```

### 2. `openwrt/luci`

Target path: `applications/luci-app-v2raya/`

The local LuCI app already uses the canonical directory, package name, menu
path and view directory (`v2raya`). Update the existing `luci-app-v2raya`
package rather than adding a second app:

- Keep `LUCI_DEPENDS:=+v2raya`.
- Change `include $(TOPDIR)/feeds/luci/luci.mk` to `include ../../luci.mk`.
- Keep the LuCI app licensed Apache-2.0. This repository now does that.
- Do not edit `po/*.po` files directly; LuCI uses Weblate. The template under
  `po/templates` is not needed upstream.
- The app is reviewed in `openwrt/luci`, not `openwrt/packages`.

Suggested commit:

```text
luci-app-v2raya: update for v2rayA 2.5.x
```

## Required Makefile changes for the packages PR

Apply these when copying the local directories into the packages feed:

1. **Package names**
   - Already canonical: `v2raya`, `v2raya-core`, `v2raya-geoip`,
     `v2raya-geosite`. No rename is needed.
2. **Remove the local `CONFLICTS`**
   - `CONFLICTS:=v2raya-nextgen`, `CONFLICTS:=v2raya-core-nextgen` and
     `CONFLICTS:=luci-app-v2raya-nextgen` only exist to migrate installations
     from this repository's old split names. Remove them upstream; the
     canonical packages replace the stock ones by name.
3. **`PKG_NAME`**
   - Already `v2raya` and `v2raya-core`.
4. **Golang include**
   - `include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk`
     → `include ../../lang/golang/golang-package.mk`
5. **LuCI include**
   - `include $(TOPDIR)/feeds/luci/luci.mk` → `include ../../luci.mk`
6. **Maintainer**
   - Packages use `PKG_MAINTAINER`; the LuCI app uses `LUCI_MAINTAINER`.
     Both must be `Name <email>`. This repository uses
     `Amr Fateem <amr.fateem@yahoo.com>`.
   - If updating Tianling Shen's package, coordinate and consider keeping him
     as a co-maintainer.
7. **`PKG_RELEASE`**
   - `1` for a new package.
   - Reset to `1` when updating `PKG_VERSION`; increment only when changing
     packaging logic/scripts/dependencies without a version bump.
8. **Test scripts**
   - `test.sh` already matches the canonical `v2raya` and `v2raya-core`
     names.
   - Do not use `grep -q` in `test.sh`; the OpenWrt CI wants the matched
     version line in the log.
   - The generic version check should pass: `v2raya --version` prints
     `2.5.13`, and `v2raya_core --version` prints
     `V2RAYA_CORE 2.5.13`.
9. **conffiles**
   - No indentation, absolute paths, directory paths end with `/`.
   - Current: `/etc/config/v2raya` only. Keep it that way.
10. **Init script**
    - procd with `USE_PROCD=1`, `start_service()`, shebang
      `#!/bin/sh /etc/rc.common`. Already correct.
    - `shfmt` is clean in this repository.

## Things reviewers will ask about

### Go 1.27

v2rayA 2.5.13 requires Go 1.27 (the service needs 1.26, the core 1.27).
The Makefiles set `GOTOOLCHAIN=go1.27.3+auto`, so the build downloads the
required toolchain. The official `xray-core` package has used the same
`GOTOOLCHAIN=... +auto` mechanism, so there is precedent, but be ready to
explain it and test with the target SDK. Build against the current
`openwrt/packages` master SDK, not only 25.12.x.

### MIPS and CGO

v2rayA's SQLite layer has no pure-Go driver on `mips*` or `loong64`. The service
package therefore enables CGO there; the core stays CGO-free. This is handled
in the Makefile. The service package must build on the `mips_24kc` and
`mips64` targets; test at least one MIPS target in the SDK.

### Source archive

v2rayA does not publish a source tarball on its GitHub releases. The codeload
archive is the only source archive available. It is a `.tar.gz`; xz/bzip2
archives do not exist upstream. The existing official `v2raya` package uses
the same codeload URL.

### Existing `xray-core` / `sing-box`

Do not add them as dependencies or conflicts. v2rayA 2.5.x uses
`v2raya_core`; the old `xray-core` dependency must be removed from the
`v2raya` package. The local app detects xray/sing-box but does not use them.

### Data packages

The old `net/v2raya` package depended only on `xray-core` and did **not**
install GeoIP/GeoSite data. v2rayA 2.5.x can download missing
`geoip.dat`/`geosite.dat` on first start, but it exits if that download
fails (offline router, blocked GitHub, no DNS yet).

The local tree keeps the data packages optional:
`v2raya` does not depend on `v2raya-geoip`/`v2raya-geosite`. This
matches the old package's footprint and avoids a mandatory ~25 MB download.

For the upstream PR, choose one:

- **Optional data (matches the old package):** do not add the data
  dependencies; document that first start needs network access.
- **Self-contained package:** depend on the data packages. Users get an
  offline-capable install, but the image grows by ~25 MB.

Either way, the data packages should remain separate so GeoIP and GeoSite can
be updated on their own release cadence and keep their different licenses.

### OpenWrt defaults that differ from upstream v2rayA

The 2.2.7 OpenWrt package behaved differently from the 2.5.x defaults:

- 2.2.7 did **not** exclude `br-*` from transparent proxy. The 2.5.x default
  excludes `br-*`, which bypasses OpenWrt's `br-lan`. The local package
  strips it from the default in `Build/Prepare`.
- 2.2.7 did **not** hijack DNS. The 2.5.x default enables DNS hijacking and
  sends client DNS through the proxy. Nodes that do not carry UDP then break
  client DNS. The local package defaults DNS mode off and patches the
  migration default for old databases.
- The local init script sets router-friendly resource defaults: `GOMEMLIMIT`
  (64 MiB), `GOMAXPROCS=2`, a 16384 descriptor ceiling, no core dumps,
  `warn` logging, one day of log retention, no QUIC sniffing, and a smaller
  DNS cache. These keep a 256 MB router responsive and reduce NAND writes.

These are deliberate OpenWrt packaging defaults, not upstream changes. Be
ready to explain them in review; they can also be split into OpenWrt-specific
patches if the maintainers prefer that.

## AI disclosure

The packages CONTRIBUTING now has an explicit AI policy. You **must** disclose
LLM usage in the pull request description or commit messages. A suitable
sentence:

> This change was produced with AI assistance (DeepSeek V4.1 Flash) and
> reviewed, built and tested by me. I understand the code and take
> responsibility for it.

Also:

- Do not post wall-of-text AI comments to maintainers.
- Do not use an autonomous agent to open the PR or reply to review comments.
- A human must verify the build and the runtime behaviour.

## Local package audit status

| Rule | Status |
| --- | --- |
| Maintainer with email | fixed (`Amr Fateem <amr.fateem@yahoo.com>`) |
| SPDX `PKG_LICENSE` | yes (`AGPL-3.0-only`, `MPL-2.0`, `GPL-3.0-only`) |
| `PKG_RELEASE` | reset to `1` before the upstream PR (local feed is at r6/r3) |
| procd init script | yes |
| `conffiles` formatting | yes |
| `test.sh` without `grep -q` | yes |
| generic version check | yes, both binaries print 2.5.13 |
| `shfmt` on init script | clean |
| CRLF line endings | no, `.gitattributes` enforces LF |
| Build tested | 25.12.6 x86_64 SDK and ipq40xx/generic ARMv7 hardware |
| Runtime tested | transparent proxy and LuCI view on OpenWrt 25.12 |
| MIPS core build | cross-compiled for `mips` and `mipsle` |
| MIPS service/CGO build | handled by Makefile; test in SDK before PR |
| Upstream package names | already canonical |
| Existing maintainer | **coordinate before touching `net/v2raya`** |

## Before opening the PR

```sh
# 1. Build from the current packages feed, not only the NextGen tree
#    (use the SDK/CI of the target branch)

# 2. Check the init script the way OpenWrt CI does
shfmt -d net/v2raya/files/v2raya.init
shellcheck -x net/v2raya/files/v2raya.init

# 3. Confirm the generic version checks
v2raya --version
v2raya_core --version

# 4. Commit with a real identity and sign-off
git commit -s -m "v2raya: update to 2.5.13"
```

The `-s` adds the required `Signed-off-by`, and your Git author name/email must
match it. GitHub noreply addresses are not accepted.
