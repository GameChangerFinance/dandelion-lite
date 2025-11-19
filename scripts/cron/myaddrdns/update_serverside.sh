#!/bin/bash



# Load the environment variables
script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last folder from the path and rename it to KLITE_HOME
SCRIPT_HOME=$(dirname "$script_dir")

source ${SCRIPT_HOME}/../../.env

echo "IPV6=${IP_V6_ENABLED}"

#FILENAME=${SCRIPT_HOME}/myaddrdns/my_ip_v6.txt
#echo $FILENAME

# IP_V6=`curl -s 'https://api64.ipify.org' > ${FILENAME}`
# echo $IP_V6

# RESPONSE=$(${SCRIPT_HOME}/myaddrdns/update.sh)

#!/bin/bash
# Based on instructions here: https://myaddr.io/
# First register domain and claim api token here: https://myaddr.io/claim
# Then pass api token on MYADDR_TOKEN variable in your .env file

# Validate required token
[[ -z ${MYADDR_TOKEN} ]] && echo "MYADDR_TOKEN variable not set, aborting..." && exit 1

# Set IP (use 'self' if MYADDR_IP is not set)
IP_TO_USE="${MYADDR_IP:-self}"

# Log update attempt
echo "[UPDATE] $(date -u)"

echo "IPv6: ${IP_V6_ENABLED}"

if [[ -n ${IP_V6_ENABLED} ]]; then
  CURRENT_IP=$(curl -s https://api64.ipify.org)
  UPDATE_URL="https://ipv6.myaddr.io/update"
  echo "Local \"https://[${CURRENT_IP}]:${HAPROXY_PORT}\""
  DNS_LOOKUP=$(dig -t AAAA +short ${MYADDR_DOMAIN}.myaddr.io)
  echo "DNS=${DNS_LOOKUP}"
else
  CURRENT_IP=$(curl -s https://api.ipify.org)
  UPDATE_URL="https://myaddr.io/update"
fi

if [[ -n ${MYADDR_DOMAIN} ]]; then
  echo "Setting 'https://${MYADDR_DOMAIN}.myaddr.io:${HAPROXY_PORT}' IP address to be '$CURRENT_IP' ..."
  
else
  echo "Setting your '<DOMAIN>.myaddr.<tools|dev|io>' domain IP address to be '$CURRENT_IP' ..."
fi

# Build request payload
POST_DATA="key=${MYADDR_TOKEN}&ip=${IP_TO_USE}"

# Include ACME challenge if set
if [[ -n ${MYADDR_ACME_CHALLENGE} ]]; then
  POST_DATA="${POST_DATA}&acme_challenge=${MYADDR_ACME_CHALLENGE}"
fi

echo "curl -s -X POST -d \"${POST_DATA}\" ${UPDATE_URL}"

# Perform the update
RESPONSE=$(curl -s -X POST -d "${POST_DATA}" "${UPDATE_URL}")
echo "Update Response: ${RESPONSE}"





echo