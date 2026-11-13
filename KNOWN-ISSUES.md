# Known issues

Status as of 2026-11-14.

These items are shelved. They don't block the packages or the router setup, and this repository isn't working on them. Anyone can pick them up.

- **DNS hijack does not serve LAN clients.** With `dnsHijack=yes`, LAN clients time out on DNS. The router's own queries work, so the DNS module runs. The module doesn't answer LAN queries, even when queried directly on port 52353. Opening port 52353 in the firewall didn't help. The setting stays off by default.
- **Stop-path patch not upstream.** `v2raya/patches/011-clean-residual-transparent-rules.patch` is a general fix for v2rayA. It hasn't been sent to the v2rayA project.
- **Not tested on MIPS hardware.** The service builds for mips with CGO. It hasn't run on a MIPS router.
