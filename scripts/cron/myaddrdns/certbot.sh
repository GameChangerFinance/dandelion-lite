#!/bin/bash
# Based on instructions here: https://myaddr.io/
# First register domain and claim api token here: https://myaddr.io/claim
# Then pass api token on MYADDR_TOKEN variable in your .env file

# Validate required token
[[ -z ${MYADDR_TOKEN} ]] && echo "MYADDR_TOKEN variable not set, aborting..." && exit 1

# Log update attempt
echo "[UPDATE] $(date -u)"

echo "Node email: ${NODE_EMAIL}"

echo "Setting '${MYADDR_DOMAIN}.myaddr.io'" 

certbot certonly --manual --non-interactive \
                 --agree-tos \
                 --email ${NODE_EMAIL} \
                 --preferred-challenges dns \
                 --manual-auth-hook /scripts/cron/myaddrdns/certbot_authentication_hook.sh \
                 -d ${MYADDR_DOMAIN}.myaddr.io
                 #  --manual-cleanup-hook /scripts/cron/myaddrdns/certbot_haproxy_hook.sh \

/scripts/cron/myaddrdns/certbot_haproxy_hook.sh

echo