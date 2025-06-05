#!/bin/sh

set -e

CERT_DIR="/etc/letsencrypt/live/${DUCKDNS_DOMAINS}.duckdns.org"
PEM_OUTPUT="/etc/letsencrypt/haproxy.pem"
WEBROOT="/var/www/certbot"

echo "Starting Certbot auto-renew loop..."

while true; do
  echo "[Renewal] Running certbot..."
  certbot renew --webroot -w "$WEBROOT"

  if [ -f "$CERT_DIR/privkey.pem" ] && [ -f "$CERT_DIR/fullchain.pem" ]; then
    echo "[Renewal] Creating combined PEM for HAProxy..."
    cat "$CERT_DIR/privkey.pem" "$CERT_DIR/fullchain.pem" > "$PEM_OUTPUT"
  else
    echo "[Renewal] PEM source files not found."
  fi

  echo "[Renewal] Sleeping for 6 hours..."
  sleep 6h
done
