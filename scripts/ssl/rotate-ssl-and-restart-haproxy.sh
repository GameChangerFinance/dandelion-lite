#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ssl/rotate-ssl-and-restart-haproxy.sh [--compose-file docker-compose.yml] [--project-name <name>]

Promotes ./configs/ssl/server.pem into ./secrets/ssl/server.pem, backs up the previous active PEM
as ./secrets/ssl/server.pem.old.N, and restarts HAProxy with docker compose.
Manual/self-signed TLS only. Disable ACME_ENABLED before using this command.

Environment alternatives:
  COMPOSE_FILE=docker-compose.yml
  PROJ_NAME=<docker-compose-project-name>
EOF
}

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
PROJECT_NAME="${PROJ_NAME:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --compose-file|--project-name)
      if [[ -z "${2:-}" || "$2" == --* ]]; then usage >&2; exit 2; fi
      if [[ "$1" == --compose-file ]]; then COMPOSE_FILE="$2"; else PROJECT_NAME="$2"; fi
      shift 2 ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CANDIDATE="${REPO_ROOT}/configs/ssl/server.pem"
ACTIVE_DIR="${REPO_ROOT}/secrets/ssl"
ACTIVE="${ACTIVE_DIR}/server.pem"

if [[ ! -f "$CANDIDATE" ]]; then
  echo "No SSL candidate found at configs/ssl/server.pem. Nothing to rotate."
  exit 0
fi

if [[ ! -s "$CANDIDATE" ]]; then
  echo "SSL candidate exists but is empty: configs/ssl/server.pem" >&2
  exit 1
fi

cd "$REPO_ROOT"
compose_args=(-f "$COMPOSE_FILE")
if [[ -n "$PROJECT_NAME" ]]; then
  compose_args=(-p "$PROJECT_NAME" "${compose_args[@]}")
fi
automatic=$(docker compose "${compose_args[@]}" config --format json |
  jq -r '.services.haproxy.environment.ACME_ENABLED // ""')
if [[ "$automatic" == true ]]; then
  echo "Automatic SSL owns secrets/ssl/server.pem. Disable ACME_ENABLED and recreate ingress before manual rotation." >&2
  exit 1
fi

# Reject links before moving certificates or replacing any backup destination.
for path in "${REPO_ROOT}/configs" "${REPO_ROOT}/configs/ssl" "$CANDIDATE" \
  "${REPO_ROOT}/secrets" "$ACTIVE_DIR" "$ACTIVE" "${ACTIVE}.old.1" "${ACTIVE}.old.2" "${ACTIVE}.old.3"; do
  if [[ -L "$path" ]]; then
    echo "Refusing SSL rotation through a symlink. Use regular files inside configs/ssl and secrets/ssl." >&2
    exit 1
  fi
done
mkdir -p "$ACTIVE_DIR"

if [[ -f "$ACTIVE" ]]; then
  for idx in 3 2 1; do
    old="${ACTIVE}.old.${idx}"
    next="${ACTIVE}.old.$((idx + 1))"
    if [[ -f "$old" && "$idx" -lt 3 ]]; then
      mv "$old" "$next"
    elif [[ -f "$old" ]]; then
      rm -f "$old"
    fi
  done
  mv "$ACTIVE" "${ACTIVE}.old.1"
fi

mv "$CANDIDATE" "$ACTIVE"
chmod 0600 "$ACTIVE"

echo "Promoted SSL PEM to secrets/ssl/server.pem."

docker compose "${compose_args[@]}" restart haproxy
