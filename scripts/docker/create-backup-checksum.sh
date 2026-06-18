#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
DLITE_HOME=$(dirname "$(dirname -- "$script_dir")")

cd "$DLITE_HOME" || exit 1
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

usage='Example usage: ./scripts/docker/create-backup-checksum.sh /path/to/backups/'
backupDir=${1:-${BACKUP_DIR:-}}

[[ -z $backupDir ]] && echo "❌ Missing BACKUP_DIR (with trailing slash). $usage" >&2 && exit 1
[[ ! -d $backupDir ]] && echo "❌ BACKUP_DIR does not exist: '$backupDir'" >&2 && exit 1

backupDir="${backupDir%/}/"
readyFile="${backupDir}READY"
hashFile="${backupDir}SHA256SUMS"

require_env() {
  local name=$1
  local value=${!name:-}
  if [[ -z $value ]]; then
    echo "❌ Missing required environment variable '$name' on .env file." >&2
    exit 1
  fi
}

require_env DLT
require_env NETWORK
require_env CARDANO_NODE_VERSION
require_env CARDANO_DB_SYNC_VERSION

echo "ℹ️ Creating backup info metadata and checksums file in '$backupDir'..."

cat > "$readyFile" <<EOF
DLT=${DLT}
NETWORK=${NETWORK}
CARDANO_NODE_VERSION=${CARDANO_NODE_VERSION}
CARDANO_DB_SYNC_VERSION=${CARDANO_DB_SYNC_VERSION}
UPDATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

# Keep the manifest compatible with plain `sha256sum -c SHA256SUMS`.
# Only backup payloads and READY are included; SHA256SUMS never hashes itself.
: > "$hashFile"
(
  cd "$backupDir" || exit 1
  if [[ -f READY ]]; then
    sha256sum READY
  fi
  find . -maxdepth 1 -type f -name '*.tar.gz' -printf '%f\n' | sort | while IFS= read -r fileName; do
    sha256sum "$fileName"
  done
) > "$hashFile"

echo
echo "ℹ️ Output:"
echo "ℹ️ Info file: $readyFile"
cat "$readyFile"
echo
echo "--------------"
echo
echo "ℹ️ Checksums file: $hashFile"
cat "$hashFile"
echo
echo "ℹ️ Remove/rename $readyFile if you want to suggest other Dandelion Lite operators to avoid downloading your current backup files"
echo "ℹ️ You can use this behaviour as a 'Maintenance Mode'"
echo 
echo "✅ Done."
