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
  echo "Setting '${MYADDR_DOMAIN}.myaddr.io'" 
  else
  echo "Setting your '<DOMAIN>.myaddr.<tools|dev|io>' domain IP address to be '$CURRENT_IP' ..."
fi

certbot certonly --dry-run --manual --non-interactive --preferred-challenges dns \
   --manual-auth-hook /scripts/cron/myaddrdns/certbot_authentication_hook.sh \
   -d ${MYADDR_DOMAIN}.myaddr.io

echo