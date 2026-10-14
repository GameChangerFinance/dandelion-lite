#!/bin/bash
# Based on instructions here: https://myaddr.io/
# First register domain and claim api token here: https://myaddr.io/claim
# Then pass api token on MYADDR_TOKEN variable in your .env file

# Validate required token
[[ -z ${MYADDR_TOKEN} ]] && echo "MYADDR_TOKEN variable not set, aborting..." && exit 1

# Set IP (use 'self' if MYADDR_IP is not set)
IP_TO_USE="${MYADDR_IP:-self}"

# API endpoint
UPDATE_URL="https://myaddr.io/update"

# Log update attempt
echo "[UPDATE] $(date -u)"

CURRENT_IP=$(curl -s https://api.ipify.org)
#CURRENT_IP=$(curl -s https://ifconfig.me)
#CURRENT_IP=$(curl -s https://icanhazip.com)

if [[ -n ${MYADDR_DOMAIN} ]]; then
  echo "Setting '${MYADDR_DOMAIN}.myaddr.<tools|dev|io>' IP address to be '$CURRENT_IP' ..."
else
  echo "Setting your '<DOMAIN>.myaddr.<tools|dev|io>' domain IP address to be '$CURRENT_IP' ..."
fi

# Keep the token out of process arguments and encode operator-supplied values.
POST_ARGS=(--data-urlencode key@- --data-urlencode "ip=${IP_TO_USE}")

# Native ACME owns TXT updates in automatic mode; stale static values must not race it.
if [[ -n ${MYADDR_ACME_CHALLENGE} && ${ACME_ENABLED:-} != true ]]; then
  POST_ARGS+=(--data-urlencode "acme_challenge=${MYADDR_ACME_CHALLENGE}")
fi

# Perform the update
RESPONSE=$(printf '%s' "$MYADDR_TOKEN" | curl -s -X POST "${POST_ARGS[@]}" "${UPDATE_URL}")
echo "Update Response: ${RESPONSE}"

echo
