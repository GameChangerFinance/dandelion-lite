#!/usr/bin/env bash

set -euo pipefail
umask 077

usage() {
  cat <<'EOF'
Usage: scripts/ssl/keygen.sh <domain-or-common-name> <file-prefix>

Creates <file-prefix>key.key, <file-prefix>cert.crt and <file-prefix>server.pem.
EOF
}

domain="${1:-}"
prefix="${2:-}"
if [[ -z "$domain" || -z "$prefix" || $# -ne 2 ]]; then
  usage >&2
  exit 2
fi
if [[ "$domain" == *[!A-Za-z0-9.*_-]* ]]; then
  echo '❌ Domain/common name may contain only letters, numbers, dots, hyphens, underscores and *.' >&2
  exit 2
fi

key="${prefix}key.key"
cert="${prefix}cert.crt"
pem="${prefix}server.pem"
cleanup() { rm -f "$key" "$cert" "$pem"; }
trap cleanup ERR

echo "ℹ️ Generating a self-signed certificate for ${domain}."
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout "$key" -out "$cert" -sha256 -subj "/CN=${domain}" >/dev/null 2>&1 || {
  echo '❌ OpenSSL could not create the self-signed certificate.' >&2
  exit 1
}
openssl x509 -in "$cert" -noout >/dev/null 2>&1 || { echo '❌ OpenSSL created an unreadable certificate.' >&2; exit 1; }
openssl pkey -in "$key" -noout >/dev/null 2>&1 || { echo '❌ OpenSSL created an unreadable private key.' >&2; exit 1; }
cat "$key" "$cert" > "$pem"
chmod 0600 "$pem"
trap - ERR
echo "✅ Self-signed PEM created at ${pem}."
