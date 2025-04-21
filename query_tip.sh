#!/bin/bash

export SOCKET_PATH=/home/maarten/src/4_project-green/dandelion-local2/node-ipc/node.socket

set -x

cardano-cli query tip \
  --testnet-magic 1 \
  --socket-path $SOCKET_PATH
