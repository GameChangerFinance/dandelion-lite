#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/ssl/check-ssl-status.sh [--compose-file <file>] [--project-name <name>]

Reports TLS mode, safe configuration readiness, active PEM presence and native ACME status.
It never prints certificate or credential contents.
EOF
}

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
PROJECT_NAME="${PROJ_NAME:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --compose-file|--project-name)
      [[ -n "${2:-}" && "$2" != --* ]] || { usage >&2; exit 2; }
      [[ "$1" != --compose-file ]] && PROJECT_NAME="$2" || COMPOSE_FILE="$2"
      shift 2 ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "❌ Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

cd "$REPO_ROOT"
compose_args=(-f "$COMPOSE_FILE")
[[ -z "$PROJECT_NAME" ]] || compose_args=(-p "$PROJECT_NAME" "${compose_args[@]}")
config=$(docker compose "${compose_args[@]}" config --format json) || { echo '❌ Could not read the resolved Compose configuration.' >&2; exit 1; }
tls=$(jq -r '.services.haproxy.environment.TLS_ENABLED // ""' <<<"$config")
acme=$(jq -r '.services.haproxy.environment.ACME_ENABLED // ""' <<<"$config")
domain=$(jq -r '.services.haproxy.environment.MYADDR_DOMAIN // ""' <<<"$config")
token=$(jq -r '.services.haproxy.environment.MYADDR_TOKEN // ""' <<<"$config")
pem="${REPO_ROOT}/secrets/ssl/server.pem"

echo 'ℹ️ SSL status'
if [[ "$tls" != true ]]; then
  echo 'Mode: plaintext (TLS_ENABLED is not true).'
elif [[ "$acme" = true ]]; then
  echo 'Mode: automatic MyAddr ACME.'
  [[ -n "$domain" ]] || echo '⚠️ MYADDR_DOMAIN is missing.'
  [[ -n "$token" ]] || echo '⚠️ MYADDR_TOKEN is missing.'
else
  echo 'Mode: manual TLS.'
fi
if [[ -f "$pem" && ! -L "$pem" && -s "$pem" ]]; then
  echo 'Active PEM: present at secrets/ssl/server.pem.'
else
  echo '⚠️ Active PEM: missing or unsafe at secrets/ssl/server.pem.'
fi

if [[ "$tls" = true && "$acme" = true && -n "$domain" && -n "$token" ]]; then
  if docker compose "${compose_args[@]}" ps -q haproxy | grep -q .; then
    echo 'Native ACME status:'
    docker compose "${compose_args[@]}" exec -T haproxy /scripts/ssl/haproxy-acme.sh status || {
      echo '⚠️ Native ACME status was unavailable; inspect HAProxy logs.' >&2
      exit 1
    }
  else
    echo '⚠️ HAProxy is not running; start it before checking native ACME status.'
  fi
fi
