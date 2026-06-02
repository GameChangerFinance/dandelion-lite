#!/usr/bin/env bash
# Example usage: ./full-backup-sync.sh "https://your-dando-node/backups/" myproject_ /tmp/backups/ backup mysecurepass

set -euo pipefail

remoteBackupURL=${1:-}
projectName=${2:-}
backupDir=${3:-}
remoteBackupUser=${4:-}
remoteBackupPassword=${5:-}

usage='Example usage: ./scripts/docker/full-backup-sync.sh "https://your-dando-node/backups/" myproject_ /tmp/backups/ backup mysecurepass'
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

[[ -z $remoteBackupURL ]] && echo "Missing remote backup files URL (with trailing slash). $usage" && exit 1
[[ -z $projectName ]] && echo "Missing docker compose project name (prefix only is fine). $usage" && exit 1
[[ -z $backupDir ]] && echo "Missing directory path for storing backup files (with trailing slash). $usage" && exit 1

if [[ -z $remoteBackupUser || -z $remoteBackupPassword ]]; then
  echo "Warning: no credentials provided, will attempt unauthenticated downloads"
  use_auth=0
else
  use_auth=1
fi

ensure_compose_volumes() {
  if ! (cd "$REPO_ROOT" && docker compose config --volumes) >/tmp/dandelion-compose-volumes.$$ 2>/tmp/dandelion-compose-volumes.err.$$; then
    echo "Could not read compose volumes with 'docker compose config --volumes'." >&2
    cat /tmp/dandelion-compose-volumes.err.$$ >&2 || true
    rm -f /tmp/dandelion-compose-volumes.$$ /tmp/dandelion-compose-volumes.err.$$
    return 1
  fi

  while IFS= read -r volume; do
    [[ -z "$volume" ]] && continue
    full_name="${projectName}${volume}"
    if ! docker volume inspect "$full_name" >/dev/null 2>&1; then
      echo "Creating missing volume: ${full_name}"
      docker volume create "$full_name" >/dev/null
    fi
  done < /tmp/dandelion-compose-volumes.$$

  rm -f /tmp/dandelion-compose-volumes.$$ /tmp/dandelion-compose-volumes.err.$$
}

echo "Ensuring Docker Compose volumes exist before downloading backups..."
ensure_compose_volumes

mkdir -p "$backupDir"

echo "Downloading backups from '$remoteBackupURL' into local dir '$backupDir'..."
echo "Will attempt to download backup files into: ${backupDir}<volume_name_without_prefix>.tar.gz"
echo

mapfile -t volumeNames < <(docker volume ls -q | sort)

for volumeName in "${volumeNames[@]}"; do
  if [[ $volumeName == "$projectName"* ]]; then
    fileName=${volumeName#"$projectName"}
    url="${remoteBackupURL}${fileName}.tar.gz"

    echo "Downloading: $url -> ${backupDir}${fileName}.tar.gz"

    aria_args=(
      --continue=true
      --max-connection-per-server=16
      --split=16
      --min-split-size=1M
      --check-certificate=false
      --out="${fileName}.tar.gz"
      --dir="$backupDir"
    )

    if [[ $use_auth -eq 1 ]]; then
      aria_args+=(--http-user="$remoteBackupUser" --http-passwd="$remoteBackupPassword")
    fi

    aria2c "${aria_args[@]}" "$url"
    echo "Downloaded $fileName.tar.gz"
  fi
done

echo
echo "Current backup files in $backupDir:"
echo

for volumeName in "${volumeNames[@]}"; do
  if [[ $volumeName == "$projectName"* ]]; then
    fileName=${volumeName#"$projectName"}
    path="${backupDir}${fileName}.tar.gz"
    if [[ -f $path ]]; then
      echo "  $fileName.tar.gz - $(ls -lh "$path" | awk '{print $5}')"
    else
      echo "  Missing: $fileName.tar.gz"
    fi
  fi
done

echo
echo "All done."
