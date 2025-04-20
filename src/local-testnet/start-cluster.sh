#!/bin/bash

cd /cluster 
rm -rf *

cd /cardano-node
./scripts/babbage/mkfiles.sh 

cd /

./sync-time.sh

./add-era-hash.sh 

./set-pgpass.sh 

# Start the first process
/cluster/node-spo1.sh &
/cluster/node-spo2.sh &
/cluster/node-spo3.sh &

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?

# cardano-db-sync --config /config/cardano-db-sync/config.yaml --socket-path /node-ipc/node.socket --state-dir /state --schema-dir /nix/store/npsidz34y67jp7sc07b2iw7s2n3fp9lj-schema

# cardano-cli byron genesis print-genesis-hash --genesis-json byron-genesis.json
# "ByronGenesisHash": "95e930b2e43f6d446d145f8b25bc1de9d40afd1caaa472567e1025077885cd93",