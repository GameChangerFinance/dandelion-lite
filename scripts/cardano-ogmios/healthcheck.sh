#!/usr/bin/env sh

set -eu

PORT="${CARDANO_OGMIOS_INTERNAL_PORT:-1337}"
URL="http://127.0.0.1:${PORT}/health"

if command -v ogmios >/dev/null 2>&1; then
  ogmios health-check --host 127.0.0.1 --port "$PORT" >/dev/null 2>&1 && exit 0
fi

if command -v curl >/dev/null 2>&1; then
  curl -fsS "$URL" >/dev/null
  exit 0
fi

wget -q -O - "$URL" >/dev/null
