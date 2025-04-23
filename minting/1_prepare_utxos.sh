export SOCKET_PATH=/home/maarten/src/1_rwa/dandelion-lite/node-ipc/node.socket

RECEIVE_WALLET=addr_test1qplwuvjy2w25g5tzh0cftl9euly66e025w7aaat452cuhtkss54kzv34zj5nwrtthxhmfslzusx7s6wg6dx2ysumxd7qdlz5d5

set -x

cardano-cli address build \
  --payment-verification-key-file ./cluster/utxo-keys/utxo1.vkey \
  --out-file addr1.addr \
  --testnet-magic 1

cardano-cli address build \
  --payment-verification-key-file ./cluster/utxo-keys/utxo2.vkey \
  --out-file addr2.addr \
  --testnet-magic 1

cardano-cli address build \
  --payment-verification-key-file ./cluster/utxo-keys/utxo3.vkey \
  --out-file addr3.addr \
  --testnet-magic 1


cardano-cli query utxo \
  --address $(cat addr1.addr) \
  --testnet-magic 1 \
  --out-file utxos.json \
  --socket-path $SOCKET_PATH

TX_HASH_0=$(jq -r 'keys[0] | split("#")[0]' utxos.json)
TX_IX_0=$(jq -r 'keys[0] | split("#")[1]' utxos.json)
AMOUNT_0=$(jq -r '.[keys[0]].value.lovelace' utxos.json)

# TX_HASH_1=$(jq -r 'keys[1] | split("#")[0]' utxos.json)
# TX_IX_1=$(jq -r 'keys[1] | split("#")[1]' utxos.json)
# AMOUNT_1=$(jq -r '.[keys[1]].value.lovelace' utxos.json)


echo "TX_HASH: $TX_HASH_0"
echo "TX_IX: $TX_IX_0"
echo "Amount: $AMOUNT_0"

FEE=400000
TOTAL_IN=$AMOUNT_0
AMOUNT1='25000000'
AMOUNT2='1000000000'
AMOUNT3='1000000000'
CHANGE=$((TOTAL_IN - AMOUNT1 - AMOUNT2 - AMOUNT3 - FEE))
echo "TOTAL_IN: " $TOTAL_IN

cardano-cli transaction build-raw \
  --tx-in "$TX_HASH_0#$TX_IX_0" \
  --tx-out $(cat addr1.addr)"+"$AMOUNT1 \
  --tx-out $(cat addr1.addr)"+"$AMOUNT2 \
  --tx-out $(cat addr1.addr)"+"$AMOUNT3 \
  --tx-out $(cat addr1.addr)"+"$CHANGE \
  --fee $FEE \
  --out-file tx.raw


cardano-cli transaction sign \
  --tx-body-file tx.raw \
  --signing-key-file ./cluster/utxo-keys/utxo1.skey \
  --testnet-magic 1 \
  --out-file tx.signed

cardano-cli transaction submit \
  --tx-file tx.signed \
  --testnet-magic 1 \
  --socket-path $SOCKET_PATH



