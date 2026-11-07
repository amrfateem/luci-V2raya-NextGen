# Contributing

Thanks for helping keep v2rayA usable on OpenWrt.

## AI-assisted contributions

This project is maintained with AI assistance. That is allowed and expected
here, but the human submitting a change is responsible for it:

* Read and understand every line you submit.
* Build it. A description of behavior you did not observe is not enough.
* Keep the AI disclosure in the README and in release notes.
* Do not present generated code as an official v2rayA release.

## Before opening a pull request

Build outputs (`dist/`, `.build/`, `.cache/`, SDK archives, `.ipk`/`.apk`
files) are ignored by Git. Do not force-add them; publish them as release
assets instead.

Run the same checks as CI:

```sh
sh -n scripts/*.sh v2raya/files/v2raya.init
shellcheck -x -S warning scripts/*.sh v2raya/files/v2raya.init

find . -name '*.json' -not -path './.git/*' -print0 |
  while IFS= read -r -d '' file; do jq empty "$file"; done

find luci-app-v2raya/htdocs -name '*.js' -print0 |
  while IFS= read -r -d '' file; do node --check "$file"; done

sh scripts/build-packages.sh 25.12.6 x86/64
```

The last command downloads the official SDK and builds all five packages.
Use `V2RAYA_NG_BUILD_DIR` to reuse the SDK between runs. After extracting a
built pair, `scripts/smoke-test.sh` starts it on loopback and checks that the
embedded web UI answers without touching the host network configuration.

## Updating upstream

Do not edit versions and hashes by hand. Run:

```sh
sh scripts/update-version.sh
```

and commit the resulting diff. The daily GitHub Action does the same thing
and opens a PR.

## Adding a build target

Release builds live in `.github/workflows/release.yml`. Add a matrix entry
with an OpenWrt release and target, for example:

```yaml
- release: 25.12.6
  target: ramips/mt7621
```

The script extracts the effective package architecture from the SDK and
names the archive after it, so targets that share an architecture can share
one build.

## Code style

* Package Makefiles follow the OpenWrt packages feed conventions and use
  tabs for recipe lines.
* Shell code is POSIX `sh`/BusyBox ash, not Bash.
* LuCI views are plain ES5-style JavaScript using the LuCI `view`, `form`,
  `fs`, `uci`, and `poll` modules. Avoid framework-specific syntax that did
  not exist in LuCI 23.05.
* Keep user-visible strings in English in the source; add a `po/<lang>/`
  file to translate them.
