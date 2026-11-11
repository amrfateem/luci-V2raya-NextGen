# Submitting this packaging to OpenWrt

## Current status (2026-11-09)

The `openwrt/packages` and `openwrt/luci` submissions are prepared and
build:

- `contrib/upstream/openwrt-packages/net/v2raya/`
- `contrib/upstream/openwrt-packages/net/v2raya-core/`
- `contrib/upstream/openwrt-luci/applications/luci-app-v2raya/`
- `contrib/upstream/PR-TEXT.md` holds the commit messages, PR titles/bodies,
  AI disclosures and the list of remaining human steps.
- `contrib/upstream/v2rayA-README-OpenWrt.md` holds the README blocks for
  the separate v2rayA docs PR, which should wait until the package is
  merged.

The upstream-shaped `v2raya-2.5.13-r1.apk` and
`v2raya-core-2.5.13-r1.apk` were built in the 25.12.6 ipq40xx SDK, together
with the LuCI app from the luci feed tree. The router runs the published
`v2raya-2.5.13-r7` pair.

The LuCI PR is included: the official app is replaced with the richer
overview, tabbed settings and log pages. The service package installs the
read-only `/usr/libexec/v2raya-detect` helper the overview uses.

Submitted on 2026-11-09:

- `openwrt/packages#31203` — <https://github.com/openwrt/packages/pull/31203>
- `openwrt/luci#9220` — <https://github.com/openwrt/luci/pull/9220>

Both PRs pass the three `FormalityCheck` runs. The multi-arch build workflows
are `action_required` until a maintainer approves them (the first-time
contributor gate); that is not a package failure. The human maintainer still
answers the review comments.

Review round 2026-11-11: the `openwrt-ai` comments on #31203 are addressed.
The `v2raya-core` commit is first, the `GOTOOLCHAIN` pin and the
`postinst`/`prerm` scriptlets are gone, the router defaults moved to
`patches/010-openwrt-defaults.patch`, and the patch was regenerated with the
buildroot's quilt `refresh` target. Current head: `9692a6b`.

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

- `openwrt/packages` gets the service and core packages. GeoIP/GeoSite data
  already exists there as `net/v2ray-geodata`, which provides
  `v2ray-geoip` and `v2ray-geosite`.
- `openwrt/luci` gets the richer LuCI app.
- The local package names already match the canonical upstream names
  (`v2raya`, `v2raya-core`, `luci-app-v2raya`); only the paths and the
  build-tree includes need adjusting.
- The AI usage must be disclosed in the PR and/or commit messages.
- The PR must carry a real name, real email and `Signed-off-by`. The packages
  project closes PRs it believes were created autonomously; the submission is
  therefore opened from the maintainer's account with an explicit AI
  disclosure, and the human answers the review.

## Two pull requests, not one

### 1. `openwrt/packages`

Target paths:

| Local directory | Upstream path | Package name |
| --- | --- | --- |
| `v2raya/` | `net/v2raya/` | `v2raya` |
| `v2raya-core/` | `net/v2raya-core/` | `v2raya-core` |

The local `v2raya-geoip/` and `v2raya-geosite/` are not submitted: the
official feed already has `net/v2ray-geodata`, which builds the
`v2ray-geoip` and `v2ray-geosite` packages and installs to
`/usr/share/v2ray`.

Notes:

- `net/v2raya` already exists in the feed and is maintained by Tianling Shen.
  This is an update/replacement of that package, not a new package. Coordinate
  with the existing maintainer before opening the PR. Do not remove their
  maintainer entry without consent; add yourself alongside them.
- `v2raya-core` is a new package. It builds the matching `v2raya_core` binary
  from the same upstream source tarball.
- `v2raya` installs `/usr/libexec/v2raya-detect` for the LuCI overview. It is
  read-only and must stay in the service package so the helper is present
  whenever the LuCI app is installable.
- The LuCI app is submitted separately to `openwrt/luci`.
- Do not submit `scripts/`, `.github/`, `README.md`, `NOTICE`, `SECURITY.md` or
  the top-level repository metadata with the package PR. Only the package
  directories and their `test.sh` files belong there.

Suggested commits:

```text
v2raya: update to 2.5.13
v2raya-core: add package
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
luci-app-v2raya: add overview and richer settings
```

The prepared tree is `contrib/upstream/openwrt-luci/applications/luci-app-v2raya/`.
It keeps the official `po/` directory, uses `LUCI_DEPENDS:=+v2raya`, and
installs the three views, the menu and the ACL. The overview calls
`/usr/libexec/v2raya-detect` and skips detection cleanly when the helper is
absent, so the app still works with v2raya 2.2.x.

## Required Makefile changes for the packages PR

Apply these when copying the local directories into the packages feed:

1. **Package names**
   - Already canonical: `v2raya`, `v2raya-core`, `luci-app-v2raya`. No rename
     is needed. The local `v2raya-geoip`/`v2raya-geosite` are not submitted;
     the feed's `v2ray-geodata` already provides those names.
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
11. **License files**
    - `v2raya` uses `../LICENSE`; the repository root is AGPL-3.0-only.
    - `v2raya-core` uses `LICENSE`; the `core/` tree is MPL-2.0. Do not
      point it at `../LICENSE`, which is the AGPL file.
12. **Detection helper**
    - `v2raya` installs `files/v2raya-detect` to `/usr/libexec/v2raya-detect`.
      The LuCI ACL grants exec on that path. Keep it read-only and 0755.

## Things reviewers will ask about

### Go 1.27

v2rayA 2.5.13 requires Go 1.27 (the service needs 1.26, the core 1.27).
The Makefiles use the feed's `golang/host` and keep its
`GOTOOLCHAIN=local`, so the build is reproducible and offline. Current
`openwrt/packages` master ships Go 1.27.4, which covers both. Do not pin a
toolchain in the package: that would download from the network and break
the buildbots. The 25.12.6 feed still defaults to Go 1.26, so a local
25.12.6 build needs its `golang1.27` host package; the PR targets master.

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

The upstream feed already contains `net/v2ray-geodata`, which builds the
`v2ray-geoip` and `v2ray-geosite` packages and installs both files into
`/usr/share/v2ray`. The service init script uses that directory as its
default. The PR keeps the data optional: `v2raya` does not depend on
`v2ray-geoip`/`v2ray-geosite`, which matches the old package's footprint and
avoids a mandatory ~25 MB download. Users can install the data packages for
an offline-capable setup.

The data stays in `v2ray-geodata` so GeoIP and GeoSite can be updated on
their own release cadence and keep their different licenses.

### OpenWrt defaults that differ from upstream v2rayA

The 2.2.7 OpenWrt package behaved differently from the 2.5.x defaults:

- 2.2.7 did **not** exclude `br-*` from transparent proxy. The 2.5.x default
  excludes `br-*`, which bypasses OpenWrt's `br-lan`. The package carries the
  previous behaviour in `patches/010-openwrt-defaults.patch`.
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
- Do not let an agent post review replies. The submission is opened from the
  maintainer's own account with the disclosure above, and the human answers
  every review comment.
- A human must verify the build and the runtime behaviour.

## Local package audit status

| Rule | Status |
| --- | --- |
| Maintainer with email | fixed (`Amr Fateem <amr.fateem@yahoo.com>`) |
| SPDX `PKG_LICENSE` | yes (`AGPL-3.0-only`, `MPL-2.0`, `GPL-3.0-only`) |
| `PKG_RELEASE` | reset to `1` before the upstream PR (local feed is at r7/r3) |
| procd init script | yes |
| `conffiles` formatting | yes |
| `test.sh` without `grep -q` | yes |
| generic version check | yes, both binaries print 2.5.13 |
| `shfmt` on init script | clean |
| CRLF line endings | no, `.gitattributes` enforces LF |
| Build tested | 25.12.6 ipq40xx (ARMv7) and ath79 (mips_24kc) SDK: service, core and LuCI app |
| Runtime tested | transparent proxy and the LuCI pages on OpenWrt 25.12 |
| `v2raya-detect` | run on the router; reports core 2.5.13 and both data files |
| MIPS core build | built in the ath79 (mips_24kc) SDK |
| MIPS service/CGO build | built in the ath79 (mips_24kc) SDK; not run on MIPS hardware |
| Upstream package names | already canonical |
| Core license file | `LICENSE` (MPL-2.0); the repo root is AGPL-3.0 |
| Existing maintainer | **coordinate before touching `net/v2raya`** |

## Before opening the PR

```sh
# 1. Build from the current feeds, not only the NextGen tree
#    (use the SDK/CI of the target branch)

# 2. Check the shell scripts and the JS/JSON
sh -n net/v2raya/files/v2raya.init
sh -n net/v2raya/files/v2raya-detect
shfmt -d net/v2raya/files/v2raya.init
shellcheck -x net/v2raya/files/v2raya.init
node -e "JSON.parse(require('fs').readFileSync('applications/luci-app-v2raya/root/usr/share/luci/menu.d/luci-app-v2raya.json'))"
node -e "JSON.parse(require('fs').readFileSync('applications/luci-app-v2raya/root/usr/share/rpcd/acl.d/luci-app-v2raya.json'))"

# 3. Confirm the generic version checks
v2raya --version
v2raya_core --version

# 4. Commit with a real identity and sign-off
git commit -s -m "v2raya: update to 2.5.13"
```

The `-s` adds the required `Signed-off-by`, and your Git author name/email must
match it. GitHub noreply addresses are not accepted.
