#!/bin/bash

podman exec -it \
       gc-node-private-testcluster-1 \
       cardano-cli transaction build \
       --tx-in 12e814d7dfc4d9755bef2ab36adbbd8faa8724ca4b9aebcb49874ef018463d8d#0 \
       --tx-out $(cat ./addresses/user1.addr)+1000000 \
       --change-address $(cat ./addresses/user1.addr) \
       --out-file tx.draft \
       --testnet-magic 5 \
       --socket-path /testcluster/private-testnet/node-spo1/node.sock

podman exec -it \
       gc-node-private-testcluster-1 \
       cardano-cli transaction sign \
       --tx-body-file /tx.draft \
       --signing-key-file /testcluster/private-testnet/addresses/user1.skey \
       --testnet-magic 5 \
       --out-file /tx.signed 

podman  cp \
       gc-node-private-testcluster-1:/tx.signed \
       $PWD/addresses/${FILE_NAME}       


podman exec -it \
       gc-node-private-testcluster-1 \
       cardano-cli transaction submit \
       --tx-file /tx.signed \
       --testnet-magic 5 \
       --socket-path /testcluster/private-testnet/node-spo1/node.sock