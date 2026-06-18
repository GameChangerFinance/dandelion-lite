#!/usr/bin/env bash

set -euo pipefail

usage='Example usage: ./scripts/docker/backup-sync.sh "https://your-dando-node/backups/" volume_name file_name /tmp/backups/ [user] [password]'

remoteBackupURL=${1:-}
volumeName=${2:-}
fileName=${3:-}
backupDir=${4:-}
remoteBackupUser=${5:-}
remoteBackupPassword=${6:-}

[[ -z $remoteBackupURL ]] && echo "❌ Missing remote backup files URL (with trailing slash). $usage" >&2 && exit 1
[[ -z $volumeName ]] && echo "❌ Missing docker compose volume name (with project name prefix!). $usage" >&2 && exit 1
[[ -z $fileName ]] && echo "❌ Missing backup filename (without file extensions!). $usage" >&2 && exit 1
[[ -z $backupDir ]] && echo "❌ Missing backup directory path (with trailing slash). $usage" >&2 && exit 1

if [[ -n $remoteBackupUser && -z $remoteBackupPassword ]] || [[ -z $remoteBackupUser && -n $remoteBackupPassword ]]; then
  echo "❌ Missing remote backup credentials: username and password must be provided together, or both left empty for unauthenticated downloads. $usage" >&2
  exit 1
fi

command -v aria2c >/dev/null 2>&1 || { echo "❌ Missing aria2c command. Install dependencies with ./scripts/dandoman.sh before downloading remote backups." >&2; exit 1; }

remoteBackupURL="${remoteBackupURL%/}/"
backupDir="${backupDir%/}/"
backupFileName="${fileName}.tar.gz"
targetPath="${backupDir}${backupFileName}"
url="${remoteBackupURL}${backupFileName}"

mkdir -p "$backupDir"

aria_args=(
  --continue=true
  --always-resume=false
  --allow-overwrite=true
  --auto-file-renaming=false
  --max-connection-per-server=16
  --split=16
  --min-split-size=1M
  --check-certificate=false
  --out="$backupFileName"
  --dir="$backupDir"
)

echo "ℹ️ Syncing volume '$volumeName' from '$url' into '$targetPath'..."

if [[ -n $remoteBackupUser ]]; then
  aria_args+=(--http-user="$remoteBackupUser" --http-passwd="$remoteBackupPassword")
fi

aria2c "${aria_args[@]}" "$url"
echo "✅ Downloaded $backupFileName"
