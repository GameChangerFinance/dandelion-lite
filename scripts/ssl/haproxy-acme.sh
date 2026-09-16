#!/bin/sh
set -eu

usage() {
    printf '%s\n' 'Usage: /scripts/ssl/haproxy-acme.sh status|renew' \
        'Run inside ingress: docker compose exec -T haproxy /scripts/ssl/haproxy-acme.sh status' \
        'renew requests immediate issuance/renewal; completion is asynchronous. Check status and ingress logs.'
}
case "${1:-}" in
    -h|--help|help) usage; exit 0 ;;
    status|renew) [ "$#" -eq 1 ] || { usage >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
esac
if [ "${ACME_ENABLED:-}" != true ] || [ -z "${MYADDR_TOKEN:-}" ] || [ -z "${MYADDR_DOMAIN:-}" ]; then
    printf '%s\n' 'Automatic SSL requires ACME_ENABLED=true, MYADDR_TOKEN and MYADDR_DOMAIN. Recreate ingress after changing .env.' >&2
    exit 1
fi
runtime() {
    printf '@1; %s\n' "$1" | socat -t 5 - UNIX-CONNECT:/var/run/haproxy-master.sock
}
status=$(runtime 'acme status')
case "$status" in
    *'@myaddr/server'*) ;;
    *) printf '%s\n' 'No automatic MyAddr certificate is configured. Check TLS mode and ingress logs.' >&2; exit 1 ;;
esac
if [ "$1" = status ]; then
    printf '%s\n' "$status"
    exit 0
fi
response=$(runtime 'acme renew @myaddr/server')
if [ -n "$response" ]; then
    printf '%s\n' "$response" >&2
    exit 1
fi
printf '%s\n' 'Renewal requested. HAProxy will apply and persist it automatically on success.' \
    'Check /scripts/ssl/haproxy-acme.sh status and docker compose logs haproxy; no manual rotation is needed.'
