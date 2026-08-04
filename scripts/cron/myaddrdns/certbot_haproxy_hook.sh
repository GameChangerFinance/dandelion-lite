#!/usr/bin/env bash

set -euo pipefail

CERT_DIR="/etc/letsencrypt/live/${MYADDR_DOMAIN}.myaddr.io"
PEM_OUTPUT="/data/ssl/server.pem"
TMP_OUTPUT="${PEM_OUTPUT}.tmp"

echo "Preparing HAProxy PEM candidate for ${MYADDR_DOMAIN}.myaddr.io"
echo "Source folder: ${CERT_DIR}"
echo "Candidate PEM: ${PEM_OUTPUT}"

if [[ -f "$CERT_DIR/privkey.pem" && -f "$CERT_DIR/fullchain.pem" ]]; then
  cat "$CERT_DIR/privkey.pem" "$CERT_DIR/fullchain.pem" > "$TMP_OUTPUT"
  chmod 0600 "$TMP_OUTPUT"
  mv "$TMP_OUTPUT" "$PEM_OUTPUT"
  echo "Candidate PEM updated. Run scripts/ssl/rotate-ssl-and-restart-haproxy.sh from the host to activate it."
else
  echo "[Renewal] PEM source files not found." >&2
  exit 1
fi
