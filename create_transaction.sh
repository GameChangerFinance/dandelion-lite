export SOCKET_PATH=/home/maarten/src/4_project-green/dandelion-local2/node-ipc/node.socket

RECEIVE_WALLET=addr_test1qplwuvjy2w25g5tzh0cftl9euly66e025w7aaat452cuhtkss54kzv34zj5nwrtthxhmfslzusx7s6wg6dx2ysumxd7qdlz5d5

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

set -x

cardano-cli query utxo \
  --address $(cat addr1.addr) \
  --testnet-magic 1 \
  --out-file utxos.json \
  --socket-path $SOCKET_PATH

TX_HASH=$(jq -r 'keys[0] | split("#")[0]' utxos.json)
TX_IX=$(jq -r 'keys[0] | split("#")[1]' utxos.json)
AMOUNT=$(jq -r '.[keys[0]].value.lovelace' utxos.json)

echo "TX_HASH: $TX_HASH"
echo "TX_IX: $TX_IX"
echo "Amount: $AMOUNT"

FEE=400000
TOTAL_IN=$AMOUNT
AMOUNT_OUT=100000000
CHANGE=$((TOTAL_IN - AMOUNT_OUT - FEE))

cardano-cli transaction build-raw \
  --tx-in "$TX_HASH#$TX_IX" \
  --tx-out $RECEIVE_WALLET"+"$AMOUNT_OUT \
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
