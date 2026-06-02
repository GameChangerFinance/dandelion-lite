#!/usr/bin/env bash

set -eu

SOCKET_PATH="${CARDANO_NODE_SOCKET_PATH:-/ipc/node.socket}"
CONFIG_DIR="${CARDANO_NODE_CONFIG_DIR:-/config/cardano-node}"
SHELLEY_GENESIS="${CONFIG_DIR}/shelley-genesis.json"

trim_json() {
  sed -n '/^[[:space:]]*{/,$p'
}

json_has_key() {
  printf '%s' "$1" | grep -Eq '"'"$2"'"[[:space:]]*:'
}

if [[ "${NETWORK:-}" == "mainnet" ]]; then
  STATUS=$(cardano-cli query tip --mainnet --socket-path "$SOCKET_PATH" 2>&1 || true)
else
  if [[ -f "$SHELLEY_GENESIS" ]]; then
    MAGIC=$(grep -E '"networkMagic"[[:space:]]*:' "$SHELLEY_GENESIS" | head -n 1 | sed -E 's/.*"networkMagic"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/')
  else
    MAGIC="${CARDANO_NODE_TESTNET_MAGIC:-1}"
  fi
  STATUS=$(cardano-cli query tip --testnet-magic "$MAGIC" --socket-path "$SOCKET_PATH" 2>&1 || true)
fi

TIP_JSON=$(printf '%s\n' "$STATUS" | trim_json)

if [[ -z "$TIP_JSON" ]] || ! printf '%s' "$TIP_JSON" | grep -Eq '^\{'; then
  echo "Initializing - node tip is not available yet" >&2
  printf '%s\n' "$STATUS" >&2
  exit 1
fi

if json_has_key "$TIP_JSON" hash && json_has_key "$TIP_JSON" block && json_has_key "$TIP_JSON" slot; then
  echo "OK - node tip is available"
  exit 0
fi

echo "Initializing - node tip JSON is missing expected fields" >&2
printf '%s\n' "$TIP_JSON" >&2
exit 1
