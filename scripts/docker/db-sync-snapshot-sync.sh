#!/bin/bash
source .env

url=${CARDANO_DB_SYNC_RESTORE_SNAPSHOT_URL} # example: https://update-cardano-mainnet.iohk.io/cardano-db-sync/13.6/db-sync-snapshot-schema-13.6-block-13078938-x86_64.tgz
fileName=${CARDANO_DB_SYNC_RESTORE_SNAPSHOT_FILENAME} # clean filename, no slashes 
backupDir=${BACKUP_DIR} # ends with slash /

[[ -z $url ]] && echo "❌ Missing CARDANO_DB_SYNC_RESTORE_SNAPSHOT_URL (find updated official sources at https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html). $usage" && exit 1
[[ -z $fileName ]] && echo "❌ Missing CARDANO_DB_SYNC_RESTORE_SNAPSHOT_FILENAME (no slashes, with extensions). $usage" && exit 1
[[ -z $backupDir ]] && echo "❌ Missing BACKUP_DIR (with trailing slash). $usage" && exit 1

echo "ℹ️ Cardano DB Sync Snapshot downloader/updater"
echo "ℹ️ Remember to periodically download this snapshot file (official sources at https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html)"
echo
echo "ℹ️ Downloading/resuming download of '${url}' in '${backupDir}${fileName}' ..."

aria2c \
    --continue=true \
    --max-connection-per-server=4 \
    --split=4 \
    --min-split-size=1M \
    --check-certificate=true \
    --out="$fileName" \
    --dir="$backupDir" \
    "$url" && echo "'${fileName}': downloaded from '${url}'" > "${backupDir}${fileName}.txt" && echo "✅ Done!"
