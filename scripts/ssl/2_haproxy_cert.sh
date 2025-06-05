#!/bin/bash

cat ../../configs/ssl/live/${DUCKDNS_DOMAINS}.duckdns.org/privkey.pem \
    ../../configs/ssl/live/${DUCKDNS_DOMAINS}.duckdns.org/fullchain.pem \
    > ../../configs/ssl/haproxy.pem