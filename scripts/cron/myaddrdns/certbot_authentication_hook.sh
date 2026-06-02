#!/usr/bin/env bash

set -euo pipefail

UPDATE_URL="https://myaddr.io/update"
PROPAGATION_SECONDS="${CERTBOT_DNS_PROPAGATION_SECONDS:-60}"

if [[ -z "${MYADDR_TOKEN:-}" || -z "${CERTBOT_VALIDATION:-}" ]]; then
  echo "Missing MYADDR_TOKEN or CERTBOT_VALIDATION for MyAddr DNS challenge." >&2
  exit 1
fi

POST_DATA="key=${MYADDR_TOKEN}&acme_challenge=${CERTBOT_VALIDATION}"
RESPONSE=$(curl -fsS -X POST -d "${POST_DATA}" "${UPDATE_URL}")
echo "MyAddr DNS challenge update submitted: ${RESPONSE}"
echo "Waiting ${PROPAGATION_SECONDS}s for DNS propagation."
sleep "$PROPAGATION_SECONDS"
