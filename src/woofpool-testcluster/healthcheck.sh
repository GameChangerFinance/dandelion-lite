#!/bin/bash

STATUS=`cardano-cli query tip \
            --socket-path /testcluster/private-testnet/node-spo1/node.sock \
            --testnet-magic ${NETWORK_MAGIC:-42}`

#echo ${STATUS} | jq '.'

SYNCPROGRESS=`echo ${STATUS} | jq '.syncProgress' | tr -d '"'`

#echo "$SYNCPROGRESS"

if [[ "$SYNCPROGRESS" == "100.00" ]]
then
#  echo 'good'
  exit 0;
else
#  echo 'bad'
  exit 1;
fi



