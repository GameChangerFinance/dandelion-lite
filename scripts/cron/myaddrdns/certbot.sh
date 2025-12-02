#!/bin/bash
# Based on instructions here: https://myaddr.io/
# First register domain and claim api token here: https://myaddr.io/claim
# Then pass api token on MYADDR_TOKEN variable in your .env file

# Validate required token
[[ -z ${CERTBOT_ENABLED} ]] && echo "CERTBOT_ENABLED variable not set, aborting..." && exit 1
[[ -z ${MYADDR_TOKEN} ]] && echo "MYADDR_TOKEN variable not set, aborting..." && exit 1
[[ -z ${MYADDR_DOMAIN} ]] && echo "MYADDR_DOMAIN variable not set, aborting..." && exit 1

# Log update attempt
echo "[SSL CERTIFICATE UPDATE] $(date -u)"

echo "Setting '${MYADDR_DOMAIN}.myaddr.io'" 

if [ -n "${CERTBOT_EMAIL:-}" ]; then
  CERTBOT_EMAIL_ARGS=(--email "$CERTBOT_EMAIL")
  echo "Using Certbot email for notifications: ${CERTBOT_EMAIL}"  
else
  # Certbot docs: allows running without email (but you won't get expiry notices)
  #   --register-unsafely-without-email  Specifying this flag enables registering an
  #   account with no email address. This is strongly discouraged... :contentReference[oaicite:1]{index=1}
  CERTBOT_EMAIL_ARGS=(--register-unsafely-without-email)  
  echo "No email set. Set CERTBOT_EMAIL=<email> to register for notifications from Certbot (Not mandatory)"  

fi

certbot certonly --manual --non-interactive \
                 --agree-tos \
                 "${CERTBOT_EMAIL_ARGS[@]}" \
                 --preferred-challenges dns \
                 --manual-auth-hook /scripts/cron/myaddrdns/certbot_authentication_hook.sh \
                 -d ${MYADDR_DOMAIN}.myaddr.io
                 #  --manual-cleanup-hook /scripts/cron/myaddrdns/certbot_haproxy_hook.sh \

/scripts/cron/myaddrdns/certbot_haproxy_hook.sh

echo