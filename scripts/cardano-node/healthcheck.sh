#!/bin/sh

EKG_HOST="${CARDANO_NODE_EKG_HOST:-127.0.0.1}"
EKG_PORT="${CARDANO_NODE_EKG_PORT:-12788}"
URL="http://${EKG_HOST}:${EKG_PORT}"

if command -v curl >/dev/null 2>&1; then
  curl -fsS "$URL" >/dev/null
  exit 0
fi

if command -v wget >/dev/null 2>&1; then
  wget -q -O - "$URL" >/dev/null
  exit 0
fi

echo "Missing curl/wget for cardano-node healthcheck" >&2
exit 1
