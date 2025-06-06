#!/bin/bash
DB_NAME=${POSTGRES_DB}
GENESIS_JSON="/config/cardano-node/shelley-genesis.json"
EPOCH_LENGTH=$(jq -r .epochLength "${GENESIS_JSON}" 2>/dev/null)
#NWMAGIC=$(psql ${DB_NAME} -h ${POSTGRES_HOST}  -qbt -c "SELECT networkmagic FROM ${KOIOS_ARTIFACTS_SCHEMA}.genesis()" | xargs)
NWMAGIC=$(jq -r .networkMagic "${GENESIS_JSON}" 2>/dev/null)
PROM_URL=
CCLI="/usr/local/bin/cardano-cli"
SOCKET="/node-ipc/node.socket"

export CARDANO_NODE_SOCKET_PATH=

echo "$(date +%F_%H:%M:%S) Running next epoch nonce calculation..."

# TODO possibly initialize EPOCH_LENGTH from database as well
PROTO_MAJ=$(psql ${DB_NAME} -h ${POSTGRES_HOST}  -c "select protocol_major from epoch_param where epoch_no = (select max(no) from epoch);" -t)
SECURITY_PARAM=$(psql ${DB_NAME} -h ${POSTGRES_HOST}  -c "select securityparam from ${KOIOS_ARTIFACTS_SCHEMA}.genesis;" -t)
ACTIVE_SLOT_COEFF=$(psql ${DB_NAME} -h ${POSTGRES_HOST}  -c "select activeslotcoeff from ${KOIOS_ARTIFACTS_SCHEMA}.genesis;" -t)
WINDOW_SIZE=2
if [[ $PROTO_MAJ -gt 8 ]]; then
  WINDOW_SIZE=3
fi
#echo "from db: security_param ${SECURITY_PARAM}, active slot coeff ${ACTIVE_SLOT_COEFF}, window size $WINDOW_SIZE based on protocol major $PROTO_MAJ"

min_slot=$(echo "${EPOCH_LENGTH} - (${WINDOW_SIZE} * (${SECURITY_PARAM} / ${ACTIVE_SLOT_COEFF}))" | bc)
if [[ -z $min_slot ]]; then
  min_slot=$((EPOCH_LENGTH * 7 / 10))
  echo "WARNING: Falling back to percent-based calculation, initialized min_slot to ${min_slot}"
fi
echo "Initialized min_slot to $min_slot"

#current_epoch=$(curl -s "${PROM_URL}" | grep epoch | awk '{print $2}')
current_epoch=$(psql ${DB_NAME} -h ${POSTGRES_HOST}  -qbt -c "SELECT epoch_no FROM ${KOIOS_ARTIFACTS_SCHEMA}.tip()" | xargs)
#current_slot_in_epoch=$(curl -s "${PROM_URL}" | grep slotInEpoch | awk '{print $2}')
current_slot_in_epoch=$(psql ${DB_NAME} -h ${POSTGRES_HOST}  -qbt -c "SELECT epoch_slot FROM ${KOIOS_ARTIFACTS_SCHEMA}.tip()" | xargs)
next_epoch=$((current_epoch + 1))

echo -e "\n\nEPOCH_LENGTH=${EPOCH_LENGTH}\nWINDOW_SIZE=${WINDOW_SIZE}\nSECURITY_PARAM=${SECURITY_PARAM}\nACTIVE_SLOT_COEFF=${ACTIVE_SLOT_COEFF}\ncurrent_epoch=${current_epoch}\current_slot_in_epoch=${current_slot_in_epoch}\next_epoch=${next_epoch}\nGENESIS_JSON=${GENESIS_JSON}\n EPOCH_LENGTH=${EPOCH_LENGTH}\n NWMAGIC=${NWMAGIC}\n PROM_URL=${PROM_URL}\n CCLI=${CCLI}\n\n"

[[ ${current_slot_in_epoch} -ge ${min_slot} ]] &&
  next_epoch_nonce=$(echo "$(${CCLI} query protocol-state --testnet-magic "${NWMAGIC}" --socket-path "${SOCKET}" | jq -r .candidateNonce)$(${CCLI} query protocol-state --testnet-magic "${NWMAGIC}" --socket-path "${SOCKET}" | jq -r .lastEpochBlockNonce)" | xxd -r -p | b2sum -b -l 256 | awk '{print $1}') &&
  psql ${DB_NAME} -h ${POSTGRES_HOST}  -c "INSERT INTO ${KOIOS_ARTIFACTS_SCHEMA}.epoch_info_cache (epoch_no, p_nonce) VALUES (${next_epoch}, '${next_epoch_nonce}') ON CONFLICT(epoch_no) DO UPDATE SET p_nonce='${next_epoch_nonce}';"

echo 
echo "$(date +%F_%H:%M:%S) Job done!"
