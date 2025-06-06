#!/bin/bash
CNODE_VNAME=cnode
DB_NAME=${POSTGRES_DB}
TR_URL="https://github.com/${CARDANO_TOKEN_REGISTRY_GITHUB_ORGANIZATION}/${CARDANO_TOKEN_REGISTRY_GITHUB_PROJECT_NAME}"
TR_SUBDIR="${CARDANO_TOKEN_REGISTRY_GITHUB_MAPPINGS_FOLDER}"
TR_DIR=${HOME}/git
TR_NAME=${CNODE_VNAME}-token-registry

echo "$(date +%F_%H:%M:%S) - START - Asset Registry Update"

if [[ ! -d "${TR_DIR}/${TR_NAME}" ]]; then
  [[ -z ${HOME} ]] && echo "HOME variable not set, aborting..." && exit 1
  mkdir -p "${TR_DIR}"
  cd "${TR_DIR}" >/dev/null || exit 1
  git clone ${TR_URL} ${TR_NAME} >/dev/null || exit 1
fi
pushd "${TR_DIR}/${TR_NAME}" >/dev/null || exit 1
git pull >/dev/null || exit 1

last_commit="$(psql ${DB_NAME} -h ${POSTGRES_HOST}  -c "select last_value from ${KOIOS_ARTIFACTS_SCHEMA}.control_table where key='asset_registry_commit'" -t | xargs)"
[[ -z "${last_commit}" ]] && last_commit="$(git rev-list HEAD | tail -n 1)"
latest_commit="$(git rev-list HEAD | head -n 1)"

[[ "${last_commit}" == "${latest_commit}" ]] && echo "$(date +%F_%H:%M:%S) - END - Asset Registry Update, no updates necessary." && exit 0

asset_cnt=0

[[ -f '.assetregistry.csv' ]] && rm -f .assetregistry.csv
while IFS= read -re assetfile; do
  if ! asset_data_csv=$(jq -er '[
      .subject[0:56],
      .subject[56:],
      .name.value,
      .description.value // "",
      .ticker.value // "",
      .url.value // "",
      .logo.value // "",
      .decimals.value // 0
      ] | @csv' "${assetfile}"); then
    echo "Failure parsing '${assetfile}', skipping..."
    continue
  fi
  echo "${asset_data_csv}" >> .assetregistry.csv
  ((asset_cnt++))
done < <(git diff --name-only "${last_commit}" "${latest_commit}" | grep ^${TR_SUBDIR})
cat << EOF > .assetregistry.sql
CREATE TEMP TABLE tmparc (like ${KOIOS_ARTIFACTS_SCHEMA}.asset_registry_cache);
\COPY tmparc FROM '.assetregistry.csv' DELIMITER ',' CSV;
INSERT INTO ${KOIOS_ARTIFACTS_SCHEMA}.asset_registry_cache SELECT DISTINCT ON (asset_policy,asset_name) * FROM tmparc ON CONFLICT(asset_policy,asset_name) DO UPDATE SET asset_policy=excluded.asset_policy, asset_name=excluded.asset_name, name=excluded.name, description=excluded.description, ticker=excluded.ticker, url=excluded.url, logo=excluded.logo,decimals=excluded.decimals;
UPDATE ${KOIOS_ARTIFACTS_SCHEMA}.asset_info_cache SET decimals=x.decimals FROM
  (SELECT ma.id, t.decimals FROM tmparc t LEFT JOIN multi_asset ma ON decode(t.asset_name,'hex')=ma.name AND decode(t.asset_policy,'hex')=ma.policy WHERE t.decimals != 0) as x
  WHERE asset_id = x.id;
EOF

psql ${DB_NAME} -h ${POSTGRES_HOST}  -qb -f .assetregistry.sql >/dev/null && rm -f .assetregistry.sql
psql ${DB_NAME} -h ${POSTGRES_HOST}  -qb -c "INSERT INTO ${KOIOS_ARTIFACTS_SCHEMA}.control_table (key, last_value) VALUES ('asset_registry_commit','${latest_commit}') ON CONFLICT(key) DO UPDATE SET last_value='${latest_commit}'"
echo "$(date +%F_%H:%M:%S) - END - Asset Registry Update, ${asset_cnt} assets added/updated for commits ${last_commit} to ${latest_commit}."
