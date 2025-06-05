#!/bin/sh

set -e

CERT_DIR="/etc/letsencrypt/live/${DUCKDNS_DOMAINS}.duckdns.org"
PEM_OUTPUT="/etc/letsencrypt/server.pem"
WEBROOT="/var/www/certbot"

echo "Starting Certbot auto-renew loop..."

echo "Duck: ${DUCKDNS_DOMAINS}.duckdns.org"
echo "SSL MAIL: ${CERTBOT_SSL_EMAIL}"

while true; do
  echo "[Renewal] Running certbot..."
   

  if [ -f "$CERT_DIR/privkey.pem" ] && [ -f "$CERT_DIR/fullchain.pem" ]; then
    echo "[Renewal] Creating combined PEM for HAProxy..."
        
    certbot renew --webroot -w "$WEBROOT"
    cat "$CERT_DIR/privkey.pem" "$CERT_DIR/fullchain.pem" > "$PEM_OUTPUT"
  else
    certbot certonly \
            --webroot -w /var/www/certbot \
            -d ${DUCKDNS_DOMAINS}.duckdns.org \
            --email ${CERTBOT_SSL_EMAIL} \
            --agree-tos \
            --non-interactive 

    if [ -f "$CERT_DIR/privkey.pem" ] && [ -f "$CERT_DIR/fullchain.pem" ]; then
      cat "$CERT_DIR/privkey.pem" "$CERT_DIR/fullchain.pem" > "$PEM_OUTPUT"
    else
      echo "[Renewal] PEM source files not found."
    fi
   
  fi

  echo "[Renewal] Sleeping for 6 hours..."
  sleep 6h
done
