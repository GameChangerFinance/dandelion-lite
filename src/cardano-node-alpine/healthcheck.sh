#!/bin/bash
echo "NETWORK=$NETWORK"

if [[ "$NETWORK" == "mainnet" ]]
then
    STATUS=`cardano-cli query tip --mainnet --socket-path /ipc/node.socket`

else
    STATUS=`cardano-cli query tip --testnet-magic 1 --socket-path /ipc/node.socket`
fi

# STATUS='{
#     "block": 2406756,
#     "epoch": 151,
#     "era": "Babbage",
#     "hash": "236e956504226ce7d1fb5e2e59f3491517f47cd547181ca4b0ea9a4727194afc",
#     "slot": 63803497,
#     "slotInEpoch": 213097,
#     "slotsToEpochEnd": 218903,
#     "syncProgress": "2.50"
# }'
# IS_JSON=$(validate_json "$STATUS")
# echo $IS_JSON

SYNC_PROGRESS=`echo $STATUS | jq -r '.syncProgress'`
EPOCH=`echo $STATUS | jq -r '.epoch'`

STATUS_INTEGER=${SYNC_PROGRESS%.*}

if [ "$STATUS_INTEGER" -ge "1" ] ; then
    echo "OK - Epoch: $EPOCH, Node sync progress: $SYNC_PROGRESS %";
    exit 0;
else
    echo "Initializing - Sync progress: $SYNC_PROGRESS % < 1%";
    exit 1;
fi

