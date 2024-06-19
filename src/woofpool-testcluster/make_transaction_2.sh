#!/bin/bash

podman exec -it \
       gc-node-private-testcluster-1 \
       cardano-cli query utxo \
       --testnet-magic 5 \
       --address $(cat ./addresses/user1.addr) \
       --socket-path /testcluster/private-testnet/node-spo1/node.sock

       