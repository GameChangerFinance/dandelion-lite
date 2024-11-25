#!/bin/bash
# Based on https://github.com/GardenOfWyers/DuckDNS/tree/master

# DuckDNS variables
[[ -z ${DUCKDNS_DOMAINS} ]] && echo "DUCKDNS_DOMAINS variable not set, aborting..." && exit 1
[[ -z ${DUCKDNS_TOKEN} ]] && echo "DUCKDNS_TOKEN variable not set, aborting..." && exit 1

SITE="https://www.duckdns.org/update?domains=${DUCKDNS_DOMAINS}&token=${DUCKDNS_TOKEN}&verbose=true&ip=${DUCKDNS_IP:-}"


# Log output stores URL HTTP_VERSION HTTP_RESPONSE_CODE TOTAL_TIME_OF_ACTION_IN_SECONDS
#echo "[$(date -u)] $(/usr/bin/curl -s -o dev/null -I -w "${SITE} HTTP/%{http_version} %{http_code} %{time_total}" $SITE)"

echo "[UPDATE] $(date -u)"
echo
/usr/bin/curl -s "${SITE}"
echo
