#!/bin/sh

echo "$(date +%F_%H:%M:%S) - START - Asset Registry Update"

[[ -z ${DBLESS_CARDANO_TOKEN_REGISTRY_DATA} ]]  && echo "DBLESS_CARDANO_TOKEN_REGISTRY_DATA variable not set, aborting..." && exit 1
[[ -z ${NETWORK} ]] && echo "NETWORK variable not set, aborting..." && exit 1

TR_DIR=$DBLESS_CARDANO_TOKEN_REGISTRY_DATA

TR_URL=https://github.com/cardano-foundation/cardano-token-registry
TR_SUBDIR=mappings
if [[ "$NETWORK" != "mainnet" ]]; then
  echo "Updating github details settings to testnet"
  TR_URL=https://github.com/input-output-hk/metadata-registry-testnet
  TR_SUBDIR=registry
fi

OUT_DIR="${TR_DIR}/data/${TR_SUBDIR}"
echo "Output directory for network '$NETWORK': '${OUT_DIR}'"

if [[ ! -d "${TR_DIR}/data" ]]; then
  mkdir -p "${TR_DIR}"
  cd "${TR_DIR}" >/dev/null || exit 1
  git clone ${TR_URL} data >/dev/null || exit 1
fi

cd "${TR_DIR}/data" >/dev/null || exit 1
git pull >/dev/null || exit 1

latest_commit="$(git rev-list HEAD | head -n 1)"
echo "Latest commit: $latest_commit"

# mv "$TR_SUBDIR" "$NETWORK" >/dev/null || exit 1

echo "$(date +%F_%H:%M:%S) - END - Asset Registry Update"
