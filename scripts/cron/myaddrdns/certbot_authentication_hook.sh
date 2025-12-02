#!/bin/bash

# API endpoint
UPDATE_URL="https://myaddr.io/update"

# Build request payload
POST_DATA="key=${MYADDR_TOKEN}&acme_challenge=${CERTBOT_VALIDATION}"

# Perform the update
RESPONSE=$(curl -s -X POST -d "${POST_DATA}" "${UPDATE_URL}")
echo "Update Response: ${RESPONSE}"

echo

sleep 5