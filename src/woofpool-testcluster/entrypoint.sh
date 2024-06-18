#!/bin/bash
git clone -b geniusyield --single-branch https://github.com/M2tec/cardano-private-testnet-setup.git /testcluster

# The 1 will make sure the testnet configuration is not deleted on restart
cd /testcluster && ./scripts/automate.sh 1
