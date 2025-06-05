#!/bin/bash

docker compose run --rm certbot certonly \
                   --webroot -w /var/www/certbot \
                   -d ${DUCKDNS_DOMAINS}.duckdns.org \
                   --email ${CERTBOT_SSL_EMAIL} \
                   --agree-tos \
                   --non-interactive 

