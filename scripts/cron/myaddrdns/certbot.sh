#!/bin/bash
# Based on instructions here: https://myaddr.io/
# First register domain and claim api token here: https://myaddr.io/claim
# Then pass api token on MYADDR_TOKEN variable in your .env file

# Validate required token
[[ -z ${MYADDR_TOKEN} ]] && echo "MYADDR_TOKEN variable not set, aborting..." && exit 1

# Log update attempt
echo "[UPDATE] $(date -u)"

echo "Setting '${MYADDR_DOMAIN}.myaddr.io'" 

certbot certonly --agree-tos \
                 --email ${NODE_EMAIL}
                 --manual --non-interactive \
                 --preferred-challenges dns \
                 --manual-auth-hook /scripts/cron/myaddrdns/certbot_authentication_hook.sh \
                 --manual-cleanup-hook /scripts/cron/myaddrdns/certbot_haproxy_hook.sh \
                 -d ${MYADDR_DOMAIN}.myaddr.io

echo