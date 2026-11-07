# Security policy

This repository packages upstream v2rayA for OpenWrt. Security issues in the
v2rayA service or the `v2raya_core` binary belong upstream:

* https://github.com/v2rayA/v2rayA/security

Report packaging-only issues here, for example:

* an init script that runs the service with the wrong privileges,
* a package that exposes the web UI more widely than documented,
* a download or checksum problem in `scripts/`,
* a CI workflow that can publish unreviewed artifacts.

Please open a private security advisory on this repository rather than a
public issue. Include the OpenWrt release, architecture, package version and
the exact commands you ran.

## Default exposure

The default `address` is `0.0.0.0:2017`, matching the upstream package. The
v2rayA web UI is password protected, but it is reachable from the LAN. If you
do not want that:

```sh
uci set v2raya.config.address='127.0.0.1:2017'
uci commit v2raya
/etc/init.d/v2raya restart
```

Then reach it through an SSH tunnel or a reverse proxy.

## Package signatures

Release archives carry a `SHA256SUMS` file. The install script verifies it
when present. The `.ipk`/`.apk` files themselves are not signed with an
OpenWrt `usign`/`apk` key; if you need repository-grade trust, build the feed
yourself from a pinned tag or sign the artifacts with your own key.
