  #!/bin/bash

  # Load the environment variables
  script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
  
  # Remove the last folder from the path and rename it to KLITE_HOME
  KLITE_HOME=$(dirname "$script_dir")
  
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

  # size=$(curl -sI "$SNAPSHOT_URL" | awk '/content-length/ {print $2}' | tr -d '\r')
  # curl -L "$SNAPSHOT_URL" | pv -s "$size" | zstd -d -c | tar -x -C "${VOLUME_FOLDER}/"
  echo "Snapshot URL: ${SNAPSHOT_URL}"
  size=$(curl -sI "$SNAPSHOT_URL" | awk 'BEGIN{IGNORECASE=1} /^content-length:/ {print $2}' | tr -d '\r')
  curl -sL "$SNAPSHOT_URL" | pv -s "$size" | zstd -d -c | tar -x -C "${VOLUME_FOLDER}/"

  # wget -c -O - "$SNAPSHOT_URL" | zstd -d -c | tar -x -C "${VOLUME_FOLDER}/"

  cd ${VOLUME_FOLDER} && rm -rf _data 
  cd ${VOLUME_FOLDER} && mv db _data

  cd "$KLITE_HOME" || exit