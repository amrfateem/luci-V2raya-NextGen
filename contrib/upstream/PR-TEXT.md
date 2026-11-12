# Upstream submission text and commands

The prepared package trees are:

```text
contrib/upstream/openwrt-packages/net/v2raya/
contrib/upstream/openwrt-packages/net/v2raya-core/
contrib/upstream/openwrt-luci/applications/luci-app-v2raya/
```

`Makefile.upstream` is used in the packages tree so this repository's own feed
scanner does not see a duplicate `v2raya` package. Rename it to `Makefile` in
the upstream clone. The LuCI tree already uses the upstream `Makefile` name
and `include ../../luci.mk`.

Both upstream projects require a human who can answer for the change. The
package and LuCI pull requests carry an explicit AI-assistance disclosure and
are submitted from the maintainer's own GitHub account. The maintainer must
answer review comments; an agent must not post review replies.

## Submitted pull requests (2026-11-12)

- `openwrt/packages#31261` — <https://github.com/openwrt/packages/pull/31261>
  - branch `amrfateem:packages:v2raya-2.5.13-r10`
  - 2 commits, 11 files; `v2raya-core` first so every commit builds.
  - all three `FormalityCheck` runs pass.
- `openwrt/luci#9243` — <https://github.com/openwrt/luci/pull/9243>
  - branch `amrfateem:luci:luci-app-v2raya-overview-r5`
  - 1 commit, 6 files; draft until `#31261` merges.
  - all three `FormalityCheck` runs pass.

The earlier `openwrt/packages#31203` and `openwrt/luci#9220` remain closed
for the record. The local package source is v2raya r10 /
luci-app-v2raya r5. The commands and texts below match the submitted
branches.

Review round 2026-11-11 (head `99f1f36`): reordered the commits so
`v2raya-core` comes first, dropped the `GOTOOLCHAIN` pin, removed the
`postinst`/`prerm` scriptlets, moved the router defaults to
`patches/010-openwrt-defaults.patch`, fixed the detection-helper comment and
the `DEPENDS` indentation, and regenerated the patch with the buildroot's
quilt `refresh` target. The patch also updates the stale `migrate_dns.go`
comment, and the PR body documents the new patch.

Stop-path fix 2026-11-11 (head `ec4e96b`): v2rayA 2.5.13 can skip the
transparent-proxy cleanup after a process restart, or when no core process
is tracked, leaving the nft table and fwmark rule behind and blackholing
traffic when the proxy or service stops. The third commit adds
`patches/011-clean-residual-transparent-rules.patch` and a `stop_service`
cleanup in `v2raya.init`. The router was fixed immediately with a
`core_hook` cleanup script; the package fix is the permanent solution.

LuCI review round 2026-11-11 (head `bac74fb`): dropped the custom
`handleSaveApply`, applied `enabled=1` before the Start action, moved the
init-script exec to the `write` ACL with only `start`/`stop`/`restart`,
unified the log poll interval, fixed the overview wording, and set the PR
to draft with a note that the rich settings and detection depend on
`openwrt/packages#31261`.

The LuCI PR body references `openwrt/packages#31261` for the rich settings
and the detection helper.

## Verified locally (2026-11-09)

Built in the OpenWrt 25.12.6 `ipq40xx/generic` SDK, target
`arm_cortex-a7_neon-vfpv4`:

```text
v2raya-2.5.13-r1.apk          (service, with /usr/libexec/v2raya-detect)
v2raya-core-2.5.13-r1.apk     (v2raya_core)
luci-app-v2raya-26.288.56989~75a306d.apk   (from the luci feed tree)
```

Checks performed:

- `patches/010-openwrt-defaults.patch` applies to `db/configure/setting.go`
  and `db/configure/migrate_dns.go`: `br-*` removed from the excluded
  interfaces, `DnsHijack=No`, `LogLevel="warn"`,
  `InboundSniffing="http,tls,quic"`, `DnsCacheSize=1024`,
  `DnsPrefetch=false`, `DnsNegativeCache=false`. The patch is in the
  buildroot's quilt format and applies with a normal `prepare`.
- The service package contains exactly `/etc/config/v2raya`,
  `/etc/init.d/v2raya`, `/lib/upgrade/keep.d/v2raya`, `/usr/bin/v2raya` and
  `/usr/libexec/v2raya-detect`.
- The core package contains `/usr/bin/v2raya_core`.
- `/usr/libexec/v2raya-detect` was also copied to a live OpenWrt 25.12
  ipq40xx router and run there. It reports
  `V2RAYA_CORE 2.5.13 (based on xray-core 26.10.31)` and finds
  `geoip_present=1` / `geosite_present=1`.
- `node --check`-equivalent parsing passed for all view modules, the JSON
  menu/ACL files parse, and the LuCI build minified the modules successfully.
- Source hashes match the Makefiles:
  `v2rayA-2.5.13.tar.gz` = `20f03a9143231e2f04b74cdcb7125c6a44b450a4a28fac92b3e64c13916ec4d9`,
  `v2raya-web-2.5.13.tar.gz` = `76774f195ee74604fbc43a48fe74e5f3363e81ec68af02d1c26feeeacc0f63ae`.
- The service and core also build for `mips_24kc` in the 25.12.6 ath79 SDK.
  The service uses CGO there; both `v2raya-2.5.13-r1.apk` and
  `v2raya-core-2.5.13-r1.apk` were produced.

Stop-path verification 2026-11-12: the router was updated to
`v2raya-2.5.13-r10` / `luci-app-v2raya-2.5.13-r5` and the temporary
`v2raya-guard` and `core_hook` were removed. Both the 2017 panel's
`DELETE /api/v2ray` call and `/etc/init.d/v2raya stop` were tested from a
LAN client: the client kept direct internet, `inet v2raya` and the fwmark
rule were gone, `fw4` still had WAN masquerade, and the proxy returned on
start. A full reboot restored `fw4`, WAN masquerade, the proxy and the
direct-domain rules.

---

## 1. openwrt/packages

One PR with two commits. `v2raya-core` must be in the same PR: `v2raya`
depends on it, so merging one without the other would break the package.

### Branch and commits

```sh
git clone https://github.com/amrfateem/packages.git
cd packages
git remote add upstream https://github.com/openwrt/packages.git
git fetch upstream master
git checkout -b v2raya-2.5.13-r10 upstream/master

rm -rf net/v2raya net/v2raya-core
cp -a /path/to/luci-V2raya-NextGen/contrib/upstream/openwrt-packages/net/v2raya .
cp -a /path/to/luci-V2raya-NextGen/contrib/upstream/openwrt-packages/net/v2raya-core .
mv net/v2raya/Makefile.upstream net/v2raya/Makefile
mv net/v2raya-core/Makefile.upstream net/v2raya-core/Makefile

git add net/v2raya-core
```

Commit 1 (the core first, so every commit builds):

```sh
git commit -s -F - <<'EOF'
v2raya-core: add package

Add the matching v2raya_core binary from the same source tarball. The
service and core must always be installed at the same version.

v2raya_core is MPL-2.0 and is pure Go; CGO stays disabled on every
target. The service keeps CGO for mips and loong64, where its SQLite
driver needs it.

Signed-off-by: Amr Fateem <amr.fateem@yahoo.com>
EOF
```

Commit 2:

```sh
git add net/v2raya
git commit -s -F - <<'EOF'
v2raya: update to 2.5.13

Update v2rayA to 2.5.13 and switch to the bundled v2raya_core. Since
2.5.x the service no longer works with an external xray-core.

Keep the OpenWrt defaults that matter on a router: the LAN bridge stays
in transparent proxy, DNS hijacking stays off, QUIC sniffing stays on,
and the Go memory, descriptor and logging defaults are sized for 256 MB
devices. Carry those defaults in patches/010-openwrt-defaults.patch so a
changed source file fails the build. Install the small read-only detection
helper used by the LuCI overview.

Drop the GeoIP parser patch; the fix is in 2.5.13. Rule data continues to
come from the existing v2ray-geoip and v2ray-geosite packages.

Signed-off-by: Amr Fateem <amr.fateem@yahoo.com>
EOF

git push -u origin v2raya-2.5.13-r10
```

Open the PR against `openwrt/packages:master`.

### PR title

```text
v2raya: update to 2.5.13
```

### PR body

```text
This updates net/v2raya to 2.5.13 and adds net/v2raya-core. Since 2.5.x
v2rayA runs only its own v2raya_core, so the old xray-core dependency no
longer works.

The service package keeps the OpenWrt defaults that were added for the
2.2.7 package and the ones that matter on a small router:

- br-lan is not excluded from transparent proxy;
- DNS hijacking stays off, including the migration default for old
  databases;
- QUIC sniffing on, so HTTP/3 traffic matches domain rules;
- warn-level logging and one day of log retention;
- GOMEMLIMIT=64MiB, GOMAXPROCS=2, a 16384 descriptor ceiling and no core
  dumps.

It also installs /usr/libexec/v2raya-detect, a read-only helper that the
updated LuCI app uses for its overview page. It only reports installed
cores and services; it never changes anything. The LuCI app degrades
cleanly when the helper is absent.

GeoIP/GeoSite data stays optional. The existing v2ray-geoip and
v2ray-geosite packages install to /usr/share/v2ray, which the init
script uses. The old GeoIP parser patch is removed because 2.5.13 already
contains that fix.

I built both packages in the 25.12.6 ipq40xx SDK and inspected the
resulting packages. The same 2.5.13 source and packaging defaults run on
an OpenWrt 25.12 ipq40xx router: the service and core start and the
transparent proxy passes LAN traffic. The fresh database defaults were
checked for the bridge, DNS, sniffing and memory settings.

The MIPS service path was not run on hardware; it uses CGO because the
SQLite driver needs it there.

I used an AI assistant to help draft the packaging and this description.
I reviewed every line, built both packages, and tested the result on the
router before submitting. I understand the change and take responsibility
for it.
```

### Before pushing, check

```sh
git diff --check
git log --format='%h %s%n%b' -2
```

The author name and e-mail must be a real identity, the e-mail must be
linked to your GitHub account, and every commit needs the sign-off.

---

## 2. openwrt/luci

The richer app is prepared under
`contrib/upstream/openwrt-luci/applications/luci-app-v2raya/`. It keeps the
official `po/` directory untouched and replaces only the Makefile, the views,
the menu and the ACL. The Makefile sets both `LUCI_MAINTAINER` (used by
luci.mk for the package metadata) and `PKG_MAINTAINER` (checked by the
formality bot).

### Branch and commit

```sh
git clone https://github.com/amrfateem/luci.git
cd luci
git remote add upstream https://github.com/openwrt/luci.git
git fetch upstream master
git checkout -b luci-app-v2raya-overview-r5 upstream/master

cp /path/to/luci-V2raya-NextGen/contrib/upstream/openwrt-luci/applications/luci-app-v2raya/Makefile \
	applications/luci-app-v2raya/Makefile
rm -rf applications/luci-app-v2raya/htdocs applications/luci-app-v2raya/root
cp -a /path/to/luci-V2raya-NextGen/contrib/upstream/openwrt-luci/applications/luci-app-v2raya/htdocs \
	applications/luci-app-v2raya/htdocs
cp -a /path/to/luci-V2raya-NextGen/contrib/upstream/openwrt-luci/applications/luci-app-v2raya/root \
	applications/luci-app-v2raya/root

git add applications/luci-app-v2raya
git commit -s -F - <<'EOF'
luci-app-v2raya: add overview and richer settings

Replace the single settings form with three pages: an overview with the
service state, versions, detected cores and start/stop controls; a tabbed
settings form for the options the 2.5.x init script supports; and a log
viewer with refresh and clear.

The overview reads /usr/libexec/v2raya-detect, which the v2raya package
installs, to report the installed core and any other proxy service.
Detection is skipped cleanly when the helper is absent, so the page also
works with the older 2.2.x package.

Signed-off-by: Amr Fateem <amr.fateem@yahoo.com>
EOF

git push -u origin luci-app-v2raya-overview-r5
```

Open the PR against `openwrt/luci:master`.

### PR title

```text
luci-app-v2raya: add overview and richer settings
```

### PR body

```text
This replaces the minimal v2rayA configuration form with three pages:

- Overview: service state, v2rayA and v2raya_core versions, listening
  address, web UI link, and start/stop/restart buttons.
- Settings: tabbed form for general, transparent proxy, logging and
  advanced options that the OpenWrt init script supports (base URL, core
  startup timeout, hooks, Go memory/scheduler limits, descriptor limit).
- Log: the tail of /var/log/v2raya/v2raya.log with refresh and clear.

The overview uses /usr/libexec/v2raya-detect from the v2raya package to
show installed cores and to warn about a second transparent-proxy stack.
When that helper is missing (v2raya 2.2.x), the overview skips detection
instead of reporting false results.

The menu and ACL use the existing admin/services/v2raya paths and the ACL
adds only the exec/read permissions the pages need. The existing po/
translations are untouched; new strings fall back to English until
Weblate regenerates them.

I built the app from the luci feed in the 25.12.6 ipq40xx SDK; the
modules pass the LuCI minifier and the same views are deployed on an
OpenWrt 25.12 ipq40xx router running v2raya 2.5.13.

I used an AI assistant to help draft the code and this description; I
reviewed every line and take responsibility for it.
```

---

## 3. v2rayA/v2rayA README

Do this after the package is merged into the official feed, otherwise the
README would claim a version that users cannot install yet.

Files: `README.md`, `README_zh.md`, `README_ru.md`.

Use the blocks in `contrib/upstream/v2rayA-README-OpenWrt.md`.

```sh
git clone https://github.com/amrfateem/v2rayA.git
cd v2rayA
git remote add upstream https://github.com/v2rayA/v2rayA.git
git fetch upstream main
git checkout -b docs/openwrt-2.5.13 upstream/main

# edit the three README files

git add README.md README_zh.md README_ru.md
git commit -s -F - <<'EOF'
docs: update the OpenWrt package version

The official OpenWrt packages feed now carries v2rayA 2.5.13 with the
matching v2raya_core. Replace the old 2.2.7.x manual-install note in all
three README files.

Signed-off-by: Amr Fateem <amr.fateem@yahoo.com>
EOF

git push -u origin docs/openwrt-2.5.13
```

### PR title

```text
docs: update the OpenWrt package version
```

### PR body

```text
The OpenWrt packages feed now carries v2rayA 2.5.13 and the matching
v2raya_core as v2raya and v2raya-core. Update the OpenWrt section in the
English, Chinese and Russian READMEs so it no longer tells users to
install 2.2.7.x binaries by hand.

This is a documentation-only change. I checked the rendered Markdown and
the install commands; there is no code to test.

I used an AI assistant to help draft the text and reviewed it before
submitting. Submitted and answered for by: Amr Fateem.
```

Do not add an AI signature or a `Co-Authored-By` trailer: the v2rayA
CONTRIBUTING file forbids it.

---

## 4. v2rayA/v2raya-openwrt

There is already an open PR, `v2rayA/v2raya-openwrt#66`, for a current-source
packaging pipeline. Do not open a competing PR. Either coordinate with that
thread or wait for it to merge, then send the small 2.5.13 version bump on
top of it.

## Ready checklist

Done in this tree:

- `net/v2raya` and `net/v2raya-core` are prepared for the packages feed and
  compile in the 25.12.6 ipq40xx SDK with the 2.5.13 source.
- `v2raya` installs `/usr/libexec/v2raya-detect`; the helper was run on the
  router and matches the installed report.
- `applications/luci-app-v2raya` is prepared for the luci feed, compiles,
  and keeps `po/` untouched.
- The OpenWrt defaults and fresh-database values were checked on a running
  system.
- The clean trees compile; both PRs are open and all three formality
  checks pass on each.
- `openwrt/packages#31261` is ready for review; `openwrt/luci#9243` is a
  draft until it merges.

Still on the human maintainer:

- Approve the pending `Test and Build` workflow runs (GitHub holds them
  for first-time contributors), then answer the review comments on both
  PRs. Do not let an agent post review replies.
- Mark `openwrt/luci#9243` ready for review after `#31261` merges.
- Coordinate with Tianling Shen and the open `v2rayA/v2raya-openwrt#66` and
  `v2rayA/v2rayA#2057` threads.
- Send the README PR only after the package PR is merged.

One risk outside the package: `web.tar.gz` is downloaded from the v2rayA
GitHub release. That CDN has returned 504/404 for some assets, so the
OpenWrt CI may fail transiently on the download. Retry the job; it is not a
packaging defect.
