#!/bin/bash

# Paths to your genesis files
BYRON_GENESIS_FILE="/cluster/genesis/byron/genesis.json"
SHELLEY_GENESIS_FILE="/cluster/genesis/shelley/genesis.json"

# Extract SystemStart from Byron genesis
SYSTEM_START=$(jq -r '.startTime' "$BYRON_GENESIS_FILE")
ISO_SYSTEM_START=$(date -u -d "@$SYSTEM_START" +"%Y-%m-%dT%H:%M:%SZ")

# Update Shelley genesis file with the same SystemStart
jq --arg systemStart "$ISO_SYSTEM_START" \
  '.systemStart = $systemStart' \
  "$SHELLEY_GENESIS_FILE" > "${SHELLEY_GENESIS_FILE}.tmp" && mv "${SHELLEY_GENESIS_FILE}.tmp" "$SHELLEY_GENESIS_FILE"

echo "Shelley genesis SystemStart updated to: $ISO_SYSTEM_START"
