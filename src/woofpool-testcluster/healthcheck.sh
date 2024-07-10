#!/bin/bash

STATUS=`cardano-cli query tip \
            --socket-path /node-ipc/testcluster/private-testnet/node-spo1/node.sock \
            --testnet-magic ${NETWORK_MAGIC:-42}`

#echo ${STATUS} | jq '.'

SYNCPROGRESS=`echo ${STATUS} | jq '.syncProgress' | tr -d '"'`

#echo "$SYNCPROGRESS"

if [[ "$SYNCPROGRESS" == "100.00" ]]
then
  # echo 'good'
  if [ ! -e /node-ipc/node.socket ]; then
    echo "Linking to /node-ipc/node.socket"
    ln -s /node-ipc/testcluster/private-testnet/node-spo1/node.sock /node-ipc/node.socket
  fi

  exit 0;
else
#  echo 'bad'
  exit 1;
fi



