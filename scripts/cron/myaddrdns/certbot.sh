#!/usr/bin/env bash
# Based on instructions here: https://myaddr.io/
# First register domain and claim api token here: https://myaddr.io/claim
# Then pass api token on MYADDR_TOKEN variable in your .env file

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  certbot.sh check-renew
  certbot.sh issue

Required env vars:
  CERTBOT_ENABLED=true
  MYADDR_TOKEN=<myaddr-api-token>
  MYADDR_DOMAIN=<subdomain-without-.myaddr.io>

Optional env vars:
  CERTBOT_EMAIL=<email>
  CERTBOT_DNS_PROPAGATION_SECONDS=60

This script writes the refreshed HAProxy PEM candidate to /data/ssl/server.pem.
Run scripts/ssl/rotate-ssl-and-restart-haproxy.sh on the host to promote it to ./secrets/ssl/server.pem.
EOF
}

ACTION="${1:-check-renew}"
case "$ACTION" in
  check-renew|issue) ;;
  -h|--help|help) usage; exit 0 ;;
  *) echo "Unknown action: $ACTION" >&2; usage; exit 1 ;;
esac

if [[ "${CERTBOT_ENABLED:-}" != "true" ]]; then
  echo "[SSL CERTIFICATE UPDATE] CERTBOT_ENABLED is not true; skipping."
  exit 0
fi

missing=0
for var in MYADDR_TOKEN MYADDR_DOMAIN; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required env var: $var" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  usage >&2
  exit 1
fi

DOMAIN="${MYADDR_DOMAIN}.myaddr.io"
# Log update attempt
echo "[SSL CERTIFICATE UPDATE] $(date -u) action=${ACTION} domain=${DOMAIN}"
echo "Writing renewed PEM candidate to /data/ssl/server.pem"

if [[ -n "${CERTBOT_EMAIL:-}" ]]; then
  CERTBOT_EMAIL_ARGS=(--email "$CERTBOT_EMAIL")
  echo "Using Certbot email for notifications: ${CERTBOT_EMAIL}"
else
  CERTBOT_EMAIL_ARGS=(--register-unsafely-without-email)
  echo "No CERTBOT_EMAIL set; registering without expiry notification email."
fi

CERTBOT_ARGS=(
  --manual
  --non-interactive
  --agree-tos
  "${CERTBOT_EMAIL_ARGS[@]}"
  --preferred-challenges dns
  --manual-auth-hook /scripts/cron/myaddrdns/certbot_authentication_hook.sh
  --manual-public-ip-logging-ok
  -d "$DOMAIN"
)

if [[ "$ACTION" == "check-renew" ]]; then
  certbot certonly --keep-until-expiring "${CERTBOT_ARGS[@]}"
else
  certbot certonly --force-renewal "${CERTBOT_ARGS[@]}"
fi

/scripts/cron/myaddrdns/certbot_haproxy_hook.sh

echo "Candidate PEM ready at /data/ssl/server.pem. Rotate it from the host when ready."
