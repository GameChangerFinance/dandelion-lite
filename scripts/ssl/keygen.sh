#/bin/bash

if [[ -z $1 ]]; then
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

echo "Generating [$2] tls secret for [$1] domain..."
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout $2key.key -out $2cert.crt -sha256 -subj "/CN=$1"

# alternative for adding extra fields:
#openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout $2key.key -out $2cert.crt -sha256 -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"

cat $2key.key $2cert.crt > $2server.pem

echo "Store '$2server.pem' as configs/ssl/server.pem for Haproxy to be able to mount it on start"

echo "Done."
exit 0
