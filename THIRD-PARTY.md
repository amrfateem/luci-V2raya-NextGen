# Third-party components

This repository is unofficial packaging. It is not affiliated with the v2rayA
authors and does not claim their endorsement.

| Component | Version | License | Upstream source | Changes |
|---|---|---|---|---|
| v2rayA service and web UI | 2.5.15 | AGPL-3.0-only | <https://github.com/v2rayA/v2rayA/tree/v2.5.15> | `v2raya/patches/011-clean-residual-transparent-rules.patch` and the DNS/logging/cache defaults in `v2raya/Makefile` |
| v2raya_core | 2.5.15 | MPL-2.0 | `core/` in the same v2rayA tag | No source changes; build settings in `v2raya-core/Makefile` |
| LuCI app | 26.317.1 | Apache-2.0 | This repository, based on the OpenWrt `luci-app-v2raya` (Apache-2.0) | Rewritten by Amr Fateem; see `luci-app-v2raya-nextgen/LICENSE` |
| Packaging, init scripts, tests | â€” | GPL-3.0-only | This repository | â€” |
| GeoIP data (optional) | v2fly releases | CC-BY-SA-4.0 | <https://github.com/v2fly/geoip> | Unmodified |
| GeoSite data (optional) | v2fly releases | MIT | <https://github.com/v2fly/domain-list-community> | Unmodified |

The Go modules used by v2rayA and v2raya_core keep their own licenses. They are
not vendored in this repository; the upstream `go.mod` and `go.sum` files list
them and their versions.

## Source

The complete corresponding source for a release is:

- the upstream v2rayA v2.5.15 tag, and
- the patches and build files in this repository at the same commit.

The upstream source is pinned by `PKG_HASH` in `v2raya/Makefile` and
`v2raya-core/Makefile`. The web UI is the upstream `web.tar.gz` release asset,
built from the upstream web source.

The source is available at:

- <https://github.com/AmrFateem/luci-V2raya-NextGen>
- <https://github.com/v2rayA/v2rayA/tree/v2.5.15>

If you use the v2rayA web UI over a network, the source above is the offer
required by AGPL section 13.
