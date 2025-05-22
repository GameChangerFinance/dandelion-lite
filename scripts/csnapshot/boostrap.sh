#!/bin/bash

source ../../.env

DB_DATA=$(docker volume inspect ${PROJ_NAME}_node-db | jq -r '.[0].Mountpoint')
VOLUME_FOLDER="${DB_DATA%/*}"
# /home/maarten/.local/share/containers/storage/volumes/dandosnap-preprod_node-db/_data

echo ${VOLUME_FOLDER}

docker compose down

echo "Network: ${NETWORK}"

if [[ "${NETWORK}" == "mainnet" ]]; then
    SNAPSHOT_URL="https://downloads.csnapshots.io/mainnet/$(wget -qO- https://downloads.csnapshots.io/mainnet/mainnet-db-snapshot.json | jq -r '.[].file_name')"
else
    SNAPSHOT_URL="https://downloads.csnapshots.io/testnet/$(wget -qO- https://downloads.csnapshots.io/testnet/testnet-db-snapshot.json | jq -r '.[].file_name')"  
fi

wget -c -O - "$SNAPSHOT_URL" | zstd -d -c | tar -x -C "${VOLUME_FOLDER}/"

cd ${VOLUME_FOLDER} && rm -rf _data 
cd ${VOLUME_FOLDER} && mv db _data 