#!/usr/bin/env bash

if [[ -z ${1:-} ]]; then
  echo "Error:Missing arguments."
  echo "USAGE:"
  echo "    ./keygen.sh <domain> <file-prefix>"
  echo
  echo "Examples:"
  echo "    ./keygen.sh *.domain.com"
  echo "    ./keygen.sh *.domain.com  domain-com-production"
  echo "    ./keygen.sh domain.com    domain-com-production"
  echo "    ./keygen.sh localhost     localhost-development"
  exit 1
fi

prefix="${2:-}"

echo "Generating [${prefix}] tls secret for [$1] domain..."
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout "${prefix}key.key" -out "${prefix}cert.crt" -sha256 -subj "/CN=$1"

# alternative for adding extra fields:
#openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout $2key.key -out $2cert.crt -sha256 -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"

cat "${prefix}key.key" "${prefix}cert.crt" > "${prefix}server.pem"

echo "Store '${prefix}server.pem' as secrets/ssl/server.pem for HAProxy, or as configs/ssl/server.pem before running rotate-ssl-and-restart-haproxy.sh"

echo "Done."
exit 0
