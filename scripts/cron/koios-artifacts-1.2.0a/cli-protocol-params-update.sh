#!/bin/bash
DB_NAME="${POSTGRES_DB}"
CCLI="${HOME}"/.local/bin/cardano-cli
SOCKET="$(dirname "$0")"/../../sockets/node.socket

echo "$(date +%F_%H:%M:%S) - START - CLI Protocol Parameters Update"
nwmagic=$(psql ${DB_NAME} -h ${POSTGRES_HOST} -qbt -c "SELECT networkmagic FROM ${KOIOS_ARTIFACTS_SCHEMA}.genesis()" | xargs)
last_epoch=$(psql ${DB_NAME} -h ${POSTGRES_HOST} -qbt -c "SELECT last_value FROM ${KOIOS_ARTIFACTS_SCHEMA}.control_table WHERE key='cli_protocol_params'" | xargs)
current_epoch=$(psql ${DB_NAME} -h ${POSTGRES_HOST} -qbt -c "SELECT epoch_no FROM ${KOIOS_ARTIFACTS_SCHEMA}.tip()" | xargs)

if [[ -z ${current_epoch} ]] || ! [[ ${current_epoch} =~ ^[0-9]+$ ]]; then
  echo "$(date +%F_%H:%M:%S) - Unable to fetch epoch_no from ${KOIOS_ARTIFACTS_SCHEMA}.tip"
  echo "$(date +%F_%H:%M:%S) - Error message: ${current_epoch}"
  exit 1
fi

[[ -n ${last_epoch} && ${last_epoch} -eq ${current_epoch} ]] && echo "$(date +%F_%H:%M:%S) - END - CLI Protocol Parameters Update, no update necessary." && exit 0

prot_params="$(${CCLI} query protocol-parameters --testnet-magic "${nwmagic}" --socket-path "${SOCKET}" 2>&1)"

if grep -q "Network.Socket.connect" <<< "${prot_params}"; then
  echo "$(date +%F_%H:%M:%S) - Node socket path wrongly configured or node not running, please verify that socket set in env file match what is used to run the node"
  echo "$(date +%F_%H:%M:%S) - Error message: ${prot_params}"
  exit 1
elif [[ -z "${prot_params}" ]] || ! jq -er . <<< "${prot_params}" &>/dev/null; then
  echo "$(date +%F_%H:%M:%S) - Failed to query protocol parameters, ensure your node is running with correct genesis (the node needs to be in sync to 1 epoch after the hardfork)"
  echo "$(date +%F_%H:%M:%S) - Error message: ${prot_params}"
  exit 1
fi

psql ${DB_NAME} -h ${POSTGRES_HOST} -qb -c "INSERT INTO ${KOIOS_ARTIFACTS_SCHEMA}.control_table (key, last_value, artifacts) VALUES ('cli_protocol_params','${current_epoch}','${prot_params}') ON CONFLICT(key) DO UPDATE SET last_value='${current_epoch}', artifacts='${prot_params}'"

echo "$(date +%F_%H:%M:%S) - END - CLI Protocol Parameters Update, updated for epoch ${current_epoch}."
