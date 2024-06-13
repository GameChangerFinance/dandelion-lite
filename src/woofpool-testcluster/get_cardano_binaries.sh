#!/bin/bash
# https://github.com/intersectmbo/cardano-node/releases
wget https://github.com/IntersectMBO/cardano-node/releases/download/8.9.3/cardano-node-8.9.3-linux.tar.gz
tar xvfz cardano-node-8.9.3-linux.tar.gz

git clone -b geniusyield --single-branch https://github.com/M2tec/cardano-private-testnet-setup.git