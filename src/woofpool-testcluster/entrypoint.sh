#!/bin/bash
git clone -b geniusyield --single-branch https://github.com/M2tec/cardano-private-testnet-setup.git /testcluster
cd /testcluster && ./scripts/automate.sh
