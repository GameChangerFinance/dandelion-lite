#!/bin/bash
export SOCKET_PATH=/home/maarten/src/1_rwa/dandelion-lite/node-ipc/node.socket

set -x

alwaysSucceedSymbol="c0f8644a01a6bf5db02f4afe30d604975e63dd274f1098a1738e561d"
tokenName1=$(echo -n "TestToken1" | xxd -ps)
tokenName2=$(echo -n "TestToken2" | xxd -ps)
tokenName3=$(echo -n "TestToken3" | xxd -ps)
tokenName4=$(echo -n "TestToken4" | xxd -ps)


cardano-cli query utxo \
  --address $(cat addr1.addr) \
  --testnet-magic 1 \
  --out-file utxos.json \
  --socket-path $SOCKET_PATH

TX_HASH_0=$(jq -r 'keys[0] | split("#")[0]' utxos.json)
TX_IX_0=$(jq -r 'keys[0] | split("#")[1]' utxos.json)
AMOUNT_0=$(jq -r '.[keys[0]].value.lovelace' utxos.json)

TX_HASH_1=$(jq -r 'keys[1] | split("#")[0]' utxos.json)
TX_IX_1=$(jq -r 'keys[1] | split("#")[1]' utxos.json)
AMOUNT_1=$(jq -r '.[keys[1]].value.lovelace' utxos.json)

echo "TX_HASH: $TX_HASH_0"
echo "TX_IX: $TX_IX_0"
echo "Amount: $AMOUNT_0"

echo "TX_HASH: $TX_HASH_1"
echo "TX_IX: $TX_IX_1"
echo "Amount: $AMOUNT_1"

cat utxo.json

# Make the tmpDir if it doesn't already exist.
mkdir -p $tmpDir

TOTAL_IN=$((AMOUNT_0 + AMOUNT_1))
FEE=10000000
AMOUNT_OUT=$((TOTAL_IN - FEE))

cardano-cli transaction build-raw \
  --tx-in "$TX_HASH_1#$TX_IX_1" \
  --tx-out "$(cat addr1.addr) + ${AMOUNT_OUT} + 1000 ${alwaysSucceedSymbol}.${tokenName1}" \
  --mint "1000 ${alwaysSucceedSymbol}.${tokenName1} + 1000 ${alwaysSucceedSymbol}.${tokenName2} + 1000 ${alwaysSucceedSymbol}.${tokenName3} + 1000 ${alwaysSucceedSymbol}.${tokenName4}" \
  --mint-script-file alwaysSucceedsMintingPolicy.plutus \
  --mint-redeemer-file unit.json \
  --mint-execution-units "(5,5)" \
  --tx-in-collateral "$TX_HASH_0#$TX_IX_0" \
  --fee ${FEE} \
  --out-file ./tx.body



cardano-cli transaction sign \
  --tx-body-file ./tx.body \
  --signing-key-file $HOME/wallets/01.skey \
  --testnet-magic 1 \
  --out-file ./tx.signed



cardano-cli transaction submit \
  --testnet-magic 1 \
  --tx-file ./tx.signed

# Add a newline after the submission response.
echo ""



