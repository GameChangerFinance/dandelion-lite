#!/bin/bash

set -e

CERT_DIR="/etc/letsencrypt/live/${MYADDR_DOMAIN}.myaddr.io"
PEM_OUTPUT="/data/ssl/server.pem"

echo "Setting up Haproxy keys for ${MYADDR_DOMAIN}.myaddr.io"
echo "SSL folder: ${CERT_DIR}"

if [ -f "$CERT_DIR/privkey.pem" ] && [ -f "$CERT_DIR/fullchain.pem" ]; then
    cat "$CERT_DIR/privkey.pem" "$CERT_DIR/fullchain.pem" > "$PEM_OUTPUT"
else
    echo "[Renewal] PEM source files not found."
fi

