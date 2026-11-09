# Upstream submission text and commands

These are drafts for you to review, edit, and submit yourself. Do not let an
agent open the pull requests. Both OpenWrt and v2rayA require a human who can
answer for the change.

The prepared package files are under:

```text
contrib/upstream/openwrt-packages/net/v2raya/
contrib/upstream/openwrt-packages/net/v2raya-core/
```

The Makefiles are named `Makefile.upstream` so this repository's own feed
scanner does not pick them up as duplicate `v2raya` packages. Rename them to
`Makefile` in the upstream tree.

Before you submit, run the build and the router test yourself. If a line below
is not true for you, remove it; do not paste claims you did not verify.

---

## 1. openwrt/packages

### Branch and commits

```sh
git clone https://github.com/<your-user>/packages.git
cd packages
git remote add upstream https://github.com/openwrt/packages.git
git fetch upstream master
git checkout -b v2raya-2.5.13 upstream/master

rm -rf net/v2raya net/v2raya-core
cp -a /path/to/luci-V2raya-NextGen/contrib/upstream/openwrt-packages/net/v2raya .
cp -a /path/to/luci-V2raya-NextGen/contrib/upstream/openwrt-packages/net/v2raya-core .
mv net/v2raya/Makefile.upstream net/v2raya/Makefile
mv net/v2raya-core/Makefile.upstream net/v2raya-core/Makefile

git add net/v2raya net/v2raya-core
git commit -s -F - <<'EOF'
v2raya: update to 2.5.13

Update v2rayA to 2.5.13 and switch to the bundled v2raya_core. Since
2.5.x the service no longer works with an external xray-core.

Keep the OpenWrt defaults that matter on a router: the LAN bridge stays
in transparent proxy, DNS hijacking stays off, QUIC sniffing is disabled,
and the Go memory, descriptor and logging defaults are sized for 256 MB
devices.

Drop the GeoIP parser patch; the fix is in 2.5.13. Rule data continues to
come from the existing v2ray-geoip and v2ray-geosite packages.

Signed-off-by: Amr Fateem <amr.fateem@yahoo.com>
EOF

git commit -s -F - <<'EOF'
v2raya-core: add package

Add the matching v2raya_core binary from the same source tarball. The
service and core must always be installed at the same version.

v2raya_core is MPL-2.0 and is pure Go; CGO stays disabled on every
target. The service keeps CGO for mips and loong64, where its SQLite
driver needs it.

Signed-off-by: Amr Fateem <amr.fateem@yahoo.com>
EOF

git push -u origin v2raya-2.5.13
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
- no QUIC sniffing;
- warn-level logging and one day of log retention;
- GOMEMLIMIT=64MiB, GOMAXPROCS=2, a 16384 descriptor ceiling and no core
  dumps.

GeoIP/GeoSite data stays optional. The existing v2ray-geoip and
v2ray-geosite packages install to /usr/share/v2ray, which the init
script uses. The old GeoIP parser patch is removed because 2.5.13 already
contains that fix.

I built both packages in the 25.12.6 ipq40xx SDK and inspected the
resulting packages. I also ran the same service/core build on an OpenWrt
25.12 ipq40xx router: the service and core start, the transparent proxy
passes LAN traffic, and the existing LuCI app loads. The fresh database
defaults were checked for the bridge, DNS, sniffing and memory settings.

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

## 2. openwrt/luci (optional)

The existing `luci-app-v2raya` already uses the canonical menu/view paths
and depends on `+v2raya`, so the 2.5.13 service update does not need a LuCI
PR. Submit the richer app only if you want the overview page and the extra
settings in the official feed.

If you do, copy `luci-app-v2raya/` from this repository over
`applications/luci-app-v2raya/`, keep the `LUCI_MAINTAINER`, use
`include ../../luci.mk`, and do not edit `po/*.po` files. The commit subject
should be:

```text
luci-app-v2raya: refresh the LuCI interface
```

---

## 3. v2rayA/v2rayA README

Do this after the package is merged into the official feed, otherwise the
README would claim a version that users cannot install yet.

Files: `README.md`, `README_zh.md`, `README_ru.md`.

Use the blocks in `contrib/upstream/v2rayA-README-OpenWrt.md`.

```sh
git clone https://github.com/<your-user>/v2rayA.git
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
submitting. Submitted and answered for by: <your GitHub username>.
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

- `net/v2raya` and `net/v2raya-core` are prepared for the packages feed.
- Both compile in the 25.12.6 ipq40xx SDK with the 2.5.13 source.
- The source patches, init script, config, keep file and test scripts are in place.
- The OpenWrt defaults and fresh-database values were checked on a running system.
- The commit messages, PR title/body and AI disclosure are drafted above.

Still on you:

- Run the build once on your machine and install the upstream-shaped pair if
  you want the PR text to say "installed the pair" without qualification.
- Create a public fork of `openwrt/packages` and open the PR from your own
  GitHub account.
- Coordinate with Tianling Shen and the open `v2rayA/v2raya-openwrt#66` and
  `v2rayA/v2rayA#2057` threads before pushing a competing change.
- Answer the review comments yourself; do not let an agent do it.

One risk outside the package: `web.tar.gz` is downloaded from the v2rayA
GitHub release. That CDN is currently returning 504/404 for some assets, so
the OpenWrt CI may fail transiently on the download. Retry the job; it is
not a packaging defect.
