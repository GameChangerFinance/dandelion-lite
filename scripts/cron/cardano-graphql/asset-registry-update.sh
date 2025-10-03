#!/bin/bash

SCHEMA=${CARDANO_GRAPHQL_SCHEMA}
CNODE_VNAME=cardano
DB_NAME=${POSTGRES_DB}
TR_URL="https://github.com/${CARDANO_TOKEN_REGISTRY_GITHUB_ORGANIZATION}/${CARDANO_TOKEN_REGISTRY_GITHUB_PROJECT_NAME}"
TR_SUBDIR="${CARDANO_TOKEN_REGISTRY_GITHUB_MAPPINGS_FOLDER}"
TR_DIR=${HOME}/git
TR_NAME=${CNODE_VNAME}-token-registry

TS() { date +%F_%H:%M:%S; }

TMP_PREFIX=".assetregistry-${SCHEMA}"
CSV="${TMP_PREFIX}.csv"
SQL="${TMP_PREFIX}.sql"
LOCKFILE="/tmp/assetregistry-${SCHEMA}.lock"

echo "$(TS) - START - Asset Registry Update for schema '${SCHEMA}'"

# Acquire a per-schema file lock (same-host concurrency)
exec {LOCK_FD}> "${LOCKFILE}"
if ! flock -n "${LOCK_FD}"; then
  echo "$(TS) - INFO  - Another run is active for schema '${SCHEMA}', exiting safely."
  exit 0
fi
echo "$(TS) - LOCK  - Acquired file lock ${LOCKFILE}"

# Ensure repo exists and is up to date
if [[ ! -d "${TR_DIR}/${TR_NAME}" ]]; then
  [[ -z ${HOME} ]] && echo "$(TS) - ERROR - HOME variable not set, aborting..." && exit 1
  echo "$(TS) - GIT   - Cloning ${TR_URL} -> ${TR_DIR}/${TR_NAME}"
  mkdir -p "${TR_DIR}"
  cd "${TR_DIR}" >/dev/null || exit 1
  git clone ${TR_URL} ${TR_NAME} >/dev/null || exit 1
fi

echo "$(TS) - GIT   - Pulling latest changes"
pushd "${TR_DIR}/${TR_NAME}" >/dev/null || exit 1
git pull >/dev/null || exit 1

echo "$(TS) - DB    - Reading last processed commit from ${SCHEMA}.control_table"
last_commit="$(psql ${DB_NAME} -h ${POSTGRES_HOST} -t -c "select last_value from ${SCHEMA}.control_table where key='asset_registry_commit'" | xargs)"
[[ -z "${last_commit}" ]] && last_commit="$(git rev-list HEAD | tail -n 1)"

latest_commit="$(git rev-list HEAD | head -n 1)"
echo "$(TS) - GIT   - last_commit=${last_commit} | latest_commit=${latest_commit}"

if [[ "${last_commit}" == "${latest_commit}" ]]; then
  echo "$(TS) - END   - No updates necessary."
  exit 0
fi

echo "$(TS) - PREP  - Building CSV of changed assets into ${CSV}"
asset_cnt=0
[[ -f "${CSV}" ]] && rm -f "${CSV}"

while IFS= read -r assetfile; do
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
    echo "$(TS) - WARN  - Failure parsing '${assetfile}', skipping..."
    continue
  fi
  echo "${asset_data_csv}" >> "${CSV}"
  ((asset_cnt++))
done < <(git diff --name-only "${last_commit}" "${latest_commit}" | grep "^${TR_SUBDIR}" || true)

echo "$(TS) - INFO  - ${asset_cnt} asset mapping file(s) changed"

# If nothing to apply, just advance the commit pointer and exit cleanly
if [[ ${asset_cnt} -eq 0 ]]; then
  echo "$(TS) - DB    - No asset CSV changes; advancing commit pointer only"
  psql ${DB_NAME} -h ${POSTGRES_HOST} -qb -c \
    "INSERT INTO ${SCHEMA}.control_table (key, last_value)
     VALUES ('asset_registry_commit','${latest_commit}')
     ON CONFLICT(key) DO UPDATE SET last_value='${latest_commit}'"
  echo "$(TS) - END   - Asset Registry Update complete (no asset rows)."
  exit 0
fi

# Ensure ON CONFLICT target exists (idempotent)
echo "$(TS) - DB    - Ensuring unique index on (${SCHEMA}.asset_registry_cache.asset_policy, asset_name)"
psql ${DB_NAME} -h ${POSTGRES_HOST} -qb -v ON_ERROR_STOP=1 -c \
  "CREATE UNIQUE INDEX IF NOT EXISTS ${SCHEMA}_asset_registry_cache_uq
     ON ${SCHEMA}.asset_registry_cache (asset_policy, asset_name);"

# Build SQL script with a per-schema advisory lock (cross-host/container safety)
echo "$(TS) - PREP  - Building SQL script ${SQL}"
cat << EOF > "${SQL}"
-- Acquire a per-schema advisory lock (stable 64-bit key from schema name)
SELECT pg_advisory_lock( ('x'||substr(md5('asset_registry:${SCHEMA}'),1,16))::bit(64)::bigint );

BEGIN;

-- Stage into a temp table with the same structure
CREATE TEMP TABLE tmparc (LIKE ${SCHEMA}.asset_registry_cache);

\\COPY tmparc FROM '${CSV}' DELIMITER ',' CSV;

-- Upsert unique rows by (asset_policy, asset_name)
INSERT INTO ${SCHEMA}.asset_registry_cache
SELECT DISTINCT ON (asset_policy, asset_name) *
FROM tmparc
ON CONFLICT (asset_policy, asset_name) DO UPDATE
SET  asset_policy = EXCLUDED.asset_policy,
     asset_name   = EXCLUDED.asset_name,
     name         = EXCLUDED.name,
     description  = EXCLUDED.description,
     ticker       = EXCLUDED.ticker,
     url          = EXCLUDED.url,
     logo         = EXCLUDED.logo,
     decimals     = EXCLUDED.decimals;

COMMIT;

-- Release advisory lock
SELECT pg_advisory_unlock( ('x'||substr(md5('asset_registry:${SCHEMA}'),1,16))::bit(64)::bigint );
EOF

echo "$(TS) - DB    - Applying CSV -> ${SCHEMA}.asset_registry_cache"
psql ${DB_NAME} -h ${POSTGRES_HOST} -qb -v ON_ERROR_STOP=1 -f "${SQL}" >/dev/null

echo "$(TS) - CLEAN - Removing temp files"
rm -f "${SQL}" "${CSV}"

echo "$(TS) - DB    - Advancing commit pointer to ${latest_commit}"
psql ${DB_NAME} -h ${POSTGRES_HOST} -qb -c \
  "INSERT INTO ${SCHEMA}.control_table (key, last_value)
   VALUES ('asset_registry_commit','${latest_commit}')
   ON CONFLICT(key) DO UPDATE SET last_value='${latest_commit}'"

echo "$(TS) - END   - Asset Registry Update, ${asset_cnt} asset row(s) added/updated for commits ${last_commit} -> ${latest_commit}."
