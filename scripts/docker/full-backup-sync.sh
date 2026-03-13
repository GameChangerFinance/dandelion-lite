#!/bin/bash
# Example usage: ./full-backup-sync.sh "https://your-dando-node/backups/" myproject_ /tmp/backups/ backup mysecurepass

remoteBackupURL=$1
projectName=$2
backupDir=$3
remoteBackupUser=$4
remoteBackupPassword=$5

usage="Example usage: ./scripts/docker/full-backup-sync.sh "https://your-dando-node/backups/" myproject_ /tmp/backups/ backup mysecurepass"

[[ -z $remoteBackupURL ]] && echo "❌ Missing remote backup files URL (with trailing slash). $usage" && exit 1
[[ -z $projectName ]] && echo "❌ Missing docker compose project name (prefix only is fine). $usage" && exit 1
[[ -z $backupDir ]] && echo "❌ Missing directory path for storing backup files (with trailing slash). $usage" && exit 1

if [[ -z $remoteBackupUser || -z $remoteBackupPassword ]]; then
  echo "⚠️  Warning: No credentials provided, will attempt unauthenticated downloads"
  use_auth=0
else
  use_auth=1
fi

echo "Downloading backups from '$remoteBackupURL' into local dir '$backupDir'..."
echo

volumeNames=$(docker volume ls -q)

echo "Ensuring ${backupDir} exists..."

mkdir -p "$backupDir"
echo

echo "Will attempt to download backup files into: ${backupDir}<volume_name_without_prefix>.tar.gz"
echo

for volumeName in $volumeNames; do
  if [[ $volumeName == "$projectName"* ]]; then
    fileName=$(echo "$volumeName" | sed "s/^${projectName}//")
    url="${remoteBackupURL}${fileName}.tar.gz"
    outputFile="${backupDir}${fileName}.tar.gz"

    echo "Downloading: $url → $outputFile"
 
    # Important: remove -k to block non HTTPS URLs
    if [[ $use_auth -eq 1 ]]; then
      aria2c \
        --continue=true \
        --max-connection-per-server=16 \
        --split=16 \
        --min-split-size=1M \
        --check-certificate=false \
        --http-user="$remoteBackupUser" \
        --http-passwd="$remoteBackupPassword" \
        --out="${fileName}.tar.gz" \
        --dir="$backupDir" \
        "$url"
    else
      aria2c \
        --continue=true \
        --max-connection-per-server=16 \
        --split=16 \
        --min-split-size=1M \
        --check-certificate=false \
        --out="${fileName}.tar.gz" \
        --dir="$backupDir" \
        "$url"
    fi

    echo "✅ Downloaded $fileName.tar.gz"
  fi
done

echo
echo "Current backup files in $backupDir:"
echo

for volumeName in $volumeNames; do
  if [[ $volumeName == "$projectName"* ]]; then
    fileName=$(echo "$volumeName" | sed "s/^${projectName}//")
    path="${backupDir}${fileName}.tar.gz"
    if [[ -f $path ]]; then
      echo "  📁 $fileName.tar.gz — $(ls -lh "$path" | awk '{print $5}')"
    else
      echo "  ⚠️  Missing: $fileName.tar.gz"
    fi
  fi
done

echo
echo "✅ All done."

exit 0
