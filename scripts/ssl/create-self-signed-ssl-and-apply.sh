#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/ssl/create-self-signed-ssl-and-apply.sh <domain-or-common-name> [--compose-file <file>] [--project-name <name>]

Creates a self-signed PEM directly in secrets/ssl/server.pem and restarts HAProxy.
It does not create certificate backups and may be used while automatic ACME is enabled.
EOF
}

domain="${1:-}"
[[ -n "$domain" && "$domain" != --* ]] || { usage >&2; exit 2; }
shift
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

temporary=$(mktemp -d)
temporary_pem=
cleanup() {
  rm -f "${temporary_pem:-}"
  rm -rf "$temporary"
}
trap cleanup EXIT
prefix="${temporary}/self-signed-"
"${REPO_ROOT}/scripts/ssl/keygen.sh" "$domain" "$prefix"

ACTIVE_DIR="${REPO_ROOT}/secrets/ssl"
ACTIVE="${ACTIVE_DIR}/server.pem"
for path in "${REPO_ROOT}/secrets" "$ACTIVE_DIR" "$ACTIVE"; do
  [[ ! -L "$path" ]] || { echo '❌ Refusing SSL application through a symlink.' >&2; exit 1; }
done
mkdir -p -m 0700 "$ACTIVE_DIR"
[[ "$(stat -c %a "$ACTIVE_DIR")" = 700 ]] || { echo '❌ secrets/ssl must have owner-only permissions (0700).' >&2; exit 1; }
temporary_pem=$(mktemp "${ACTIVE_DIR}/.server.pem.XXXXXX")
cp "${prefix}server.pem" "$temporary_pem"
chmod 0600 "$temporary_pem"
mv -f "$temporary_pem" "$ACTIVE"
temporary_pem=

cd "$REPO_ROOT"
compose_args=(-f "$COMPOSE_FILE")
[[ -z "$PROJECT_NAME" ]] || compose_args=(-p "$PROJECT_NAME" "${compose_args[@]}")
docker compose "${compose_args[@]}" restart haproxy
echo '✅ Self-signed SSL applied at secrets/ssl/server.pem and HAProxy restarted.'
echo 'ℹ️ This temporary certificate can be replaced automatically by HAProxy ACME when issuance succeeds.'
