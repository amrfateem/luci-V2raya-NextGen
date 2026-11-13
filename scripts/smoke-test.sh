#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
#
# Developer smoke test for a built service and core pair.  It starts v2rayA
# on loopback with a throw-away config directory and checks that the embedded
# web UI answers.  It does not touch the host network configuration.
#
# Usage: sh scripts/smoke-test.sh [v2raya] [v2raya_core] [assets-dir]

set -eu

BIN="${1:-/usr/bin/v2raya}"
CORE="${2:-/usr/bin/v2raya_core}"
ASSETS="${3:-/usr/share/v2raya}"

WORK=$(mktemp -d 2>/dev/null || mktemp -d -t v2raya-smoke)
PID=""
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT INT TERM

PORT=20170

"$BIN" \
	--config "$WORK/config" \
	--address "127.0.0.1:$PORT" \
	--v2ray-bin "$CORE" \
	--v2ray-assetsdir "$ASSETS" \
	--log-file "$WORK/v2raya.log" \
	--passcheckroot \
	>"$WORK/stdout.log" 2>&1 &
PID=$!

i=0
while [ "$i" -lt 30 ]; do
	sleep 1
	if curl -fsS "http://127.0.0.1:$PORT/" -o "$WORK/index.html" 2>/dev/null; then
		echo "OK: web UI answered on 127.0.0.1:$PORT"
		head -c 160 "$WORK/index.html"
		echo
		exit 0
	fi
	i=$((i + 1))
done

echo "FAILED: web UI did not answer; log follows" >&2
cat "$WORK/v2raya.log" 2>/dev/null || true
cat "$WORK/stdout.log" 2>/dev/null || true
exit 1
