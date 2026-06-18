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
command -v md5sum >/dev/null 2>&1 || { echo "❌ Missing md5sum command. Install dependencies with ./scripts/dandoman.sh before creating backup checksums." >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "❌ Missing sha256sum command. Install dependencies with ./scripts/dandoman.sh before creating backup checksums." >&2; exit 1; }

backupDir="${backupDir%/}/"
readyFile="${backupDir}READY"
md5File="${backupDir}MD5SUMS"
sha256File="${backupDir}SHA256SUMS"

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

ready_value() {
  local key=$1
  local sourceFile=${READY_SOURCE_FILE:-}
  local value

  if [[ -n $sourceFile && -f $sourceFile ]]; then
    value=$(awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$sourceFile")
    [[ -n $value ]] && { printf '%s' "$value"; return; }
  fi

  printf '%s' "${!key:-}"
}

human_size() {
  ls -lh "$1" | awk '{print $5}'
}

write_checksum_file() {
  local commandName=$1
  local outFile=$2

  : > "$outFile"
  (
    cd "$backupDir" || exit 1
    if [[ -f READY ]]; then
      "$commandName" READY
    fi
    find . -maxdepth 1 -type f -name '*.tar.gz' -printf '%f\n' | sort | while IFS= read -r fileName; do
      "$commandName" "$fileName"
    done
  ) > "$outFile"
}

echo "ℹ️ Creating backup info metadata and checksums file in '$backupDir'..."

cat > "$readyFile" <<EOF
DLT=$(ready_value DLT)
NETWORK=$(ready_value NETWORK)
CARDANO_NODE_VERSION=$(ready_value CARDANO_NODE_VERSION)
CARDANO_DB_SYNC_VERSION=$(ready_value CARDANO_DB_SYNC_VERSION)
UPDATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

# Keep manifests compatible with plain `md5sum -c MD5SUMS` and
# `sha256sum -c SHA256SUMS`. Only backup payloads and READY are included.
write_checksum_file md5sum "$md5File"
write_checksum_file sha256sum "$sha256File"

echo
echo "ℹ️ Output:"
echo "ℹ️ Info file: $readyFile"
cat "$readyFile"
echo
echo "--------------"
echo
echo "ℹ️ MD5 fast-checks file: $md5File"
cat "$md5File"
echo
echo "--------------"
echo
echo "ℹ️ SHA256 integrity checks file: $sha256File"
cat "$sha256File"
echo
echo "--------------"
echo
echo "ℹ️ Backup file sizes:"
find "$backupDir" -maxdepth 1 -type f -name '*.tar.gz' -printf '%f\n' | sort | while IFS= read -r fileName; do
  echo "  $fileName - $(human_size "${backupDir}${fileName}")"
done
echo
echo "ℹ️ Remove/rename $readyFile if you want to suggest other Dandelion Lite operators to avoid downloading your current backup files"
echo "ℹ️ You can use this behaviour as a 'Maintenance Mode'"
echo 
echo "✅ Done."
