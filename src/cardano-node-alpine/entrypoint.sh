#!/bin/bash

./node_exporter &

cardano-node run \
  --topology /config/cardano-node/topology.json \
  --database-path /db \
  --port 3000 \
  --host-addr 0.0.0.0 \
  --config /config/cardano-node/config.json \
  --socket-path /ipc/node.socket

