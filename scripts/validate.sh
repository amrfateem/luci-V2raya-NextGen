#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Run the local checks that CI runs.  Missing optional tools are skipped.

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

echo "==> Shell syntax"
for file in scripts/*.sh v2raya/files/v2raya.init; do
	sh -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
	echo "==> ShellCheck"
	shellcheck -x -S warning scripts/*.sh v2raya/files/v2raya.init
else
	echo "==> ShellCheck not installed, skipping"
fi

if command -v jq >/dev/null 2>&1; then
	echo "==> JSON"
	find . -name '*.json' -not -path './.git/*' -exec jq empty {} \;
else
	echo "==> jq not installed, skipping JSON checks"
fi

if command -v node >/dev/null 2>&1; then
	echo "==> JavaScript syntax"
	find luci-app-v2raya/htdocs -name '*.js' -exec node --check {} \;
else
	echo "==> node not installed, skipping JavaScript checks"
fi

if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
	echo "==> Workflow YAML"
	python3 - <<'PY'
import glob
import yaml

for path in sorted(glob.glob('.github/workflows/*.yml')):
    with open(path, encoding='utf-8') as handle:
        yaml.safe_load(handle)
    print('   ', path)
PY
else
	echo "==> PyYAML not installed, skipping workflow checks"
fi

echo "==> Whitespace"
if git rev-parse --git-dir >/dev/null 2>&1; then
	git diff --check
else
	echo "    not a git checkout, skipping"
fi

echo "==> All available checks passed"
