#!/bin/sh
# Data Plane API exec DNS-01 provider. https://myaddr.tools/
set -eu

log() { printf '%s %s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2" >&2; }
fail() { log '❌' "MyAddr ACME: $1"; exit 1; }
trim_crlf() {
    # MyAddr returns text/plain bodies; tolerate trailing line endings only.
    awk 'BEGIN { ORS="" } { text = text $0 "\n" } END { sub(/\n$/, "", text); gsub(/\r$/, "", text); print text }'
}
sanitize_body() {
    body=$(printf '%s' "$1" | tr '\r\n' '  ')
    [ -z "${MYADDR_TOKEN:-}" ] || body=$(printf '%s' "$body" | sed "s/$(printf '%s' "$MYADDR_TOKEN" | sed 's/[.[\*^$()+?{}|\\/]/\\&/g')/<redacted-token>/g")
    [ -z "${REC_DATA:-}" ] || body=$(printf '%s' "$body" | sed "s/$(printf '%s' "$REC_DATA" | sed 's/[.[\*^$()+?{}|\\/]/\\&/g')/<redacted-challenge>/g")
    printf '%.200s' "$body"
}
usage() {
    printf '%s\n' 'Usage: invoked by HAProxy Data Plane API with ACTION, ZONE, REC_NAME, REC_TYPE, REC_DATA.' \
        'Requires ACME_ENABLED=true, MYADDR_DOMAIN (registration label), MYADDR_TOKEN.'
}
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
[ "$#" -eq 0 ] || { usage >&2; exit 2; }
[ "${ACME_ENABLED:-}" = true ] || fail 'ACME_ENABLED must be true.'
[ -n "${MYADDR_TOKEN:-}" ] || fail 'MYADDR_TOKEN is missing.'
domain=$(printf '%s' "${MYADDR_DOMAIN:-}" | tr '[:upper:]' '[:lower:]')
case "$domain" in
    ''|*[!a-z0-9-]*|-*|*-) fail 'MYADDR_DOMAIN must be a registration label, without .myaddr.io.' ;;
esac
[ "${#MYADDR_DOMAIN}" -le 63 ] || fail 'MYADDR_DOMAIN exceeds 63 characters.'
[ "${REC_TYPE:-}" = TXT ] || fail 'Only TXT challenges are supported.'
zone=${ZONE:-}
record=$(printf '%s' "${REC_NAME:-}" | tr '[:upper:]' '[:lower:]')
[ "${zone%.}" = myaddr.io ] || fail 'Unexpected DNS zone.'
[ "${record%.}" = "_acme-challenge.${domain}.myaddr.io" ] || fail 'Unexpected challenge name.'

action=${ACTION:-}
case "$action" in
    delete)
        # MyAddr expires TXT challenges automatically. DELETE would remove IPs.
        log 'ℹ️' "MyAddr ACME delete ignored for ${record%.}; MyAddr expires TXT challenges automatically."
        exit 0 ;;
    set|append) ;;
    *) fail 'Unsupported action; expected set, append or delete.' ;;
esac
case "${REC_DATA:-}" in
    ''|*[!A-Za-z0-9_-]*) fail 'Invalid DNS-01 challenge value.' ;;
esac
[ "${#REC_DATA}" -eq 43 ] || fail 'Expected a 43-character DNS-01 SHA-256 value.'

# Read the credential from stdin, never from a URL or process argument.
log 'ℹ️' "MyAddr ACME ${action} request for ${record%.}."
response=$(printf '%s' "$MYADDR_TOKEN" | curl --silent --show-error \
    --proto '=https' --connect-timeout 10 --max-time 30 --max-filesize 4096 \
    --data-urlencode key@- --data-urlencode "acme_challenge=$REC_DATA" \
    --write-out '\n%{http_code}' https://myaddr.tools/update) || fail 'Request failed; check outbound HTTPS and MyAddr availability.'
code=${response##*'
'}
body=${response%'
'*}
body_cmp=$(printf '%s' "$body" | trim_crlf)
[ "$code" = 200 ] || fail "Provider returned HTTP $code: $(sanitize_body "$body")"
# Do not echo an untrusted provider response (it could contain credentials).
[ "$body_cmp" = OK ] || fail "Provider did not return OK: $(sanitize_body "$body")"
log '✅' "MyAddr ACME ${action} accepted for ${record%.}."
