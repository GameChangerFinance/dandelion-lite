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

echo "IPv6: ${MYADDR_IP_V6_ENABLED}"

if [[ -n ${MYADDR_IP_V6_ENABLED} ]]; then
  CURRENT_IP=`cat /scripts/cron/myaddrdns/my_ip_v6.txt`
  IP_TO_USE=${CURRENT_IP}
  UPDATE_URL="https://ipv6.myaddr.io/update"
else
  CURRENT_IP=$(curl -s https://api.ipify.org)
fi


#CURRENT_IP=$(curl -s https://ifconfig.me)
#CURRENT_IP=$(curl -s https://icanhazip.com)

if [[ -n ${MYADDR_DOMAIN} ]]; then
  echo "Setting '${MYADDR_DOMAIN}.myaddr.<tools|dev|io>' IP address to be '$CURRENT_IP' ..."
else
  echo "Setting your '<DOMAIN>.myaddr.<tools|dev|io>' domain IP address to be '$CURRENT_IP' ..."
fi

# Build request payload
POST_DATA="key=${MYADDR_TOKEN}&ip=${IP_TO_USE}"

# Include ACME challenge if set
if [[ -n ${MYADDR_ACME_CHALLENGE} ]]; then
  POST_DATA="${POST_DATA}&acme_challenge=${MYADDR_ACME_CHALLENGE}"
fi

echo "curl -s -X POST -d "${POST_DATA}" "${UPDATE_URL}""

# Perform the update
RESPONSE=$(curl -s -X POST -d "${POST_DATA}" "${UPDATE_URL}")
echo "Update Response: ${RESPONSE}"

echo
