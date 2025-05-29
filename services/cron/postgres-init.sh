#!/bin/bash

CURRTIME=$(date +%s)
echo "Starting postgres-init script at `date`"

BLOCK_TABLE_EXISTS=`psql -Aqt -h ${POSTGRES_HOST} -c "select exists(select 1 from information_schema.tables where table_name = 'block' and table_schema = 'public')"`
echo "BLOCK TABLE EXISTS: $BLOCK_TABLE_EXISTS"

if [[ $BLOCK_TABLE_EXISTS == "f" ]]; then
  echo "Block table in public schema does not exist yet, aborting"
  exit 1
fi

DATE_DIFF=$(( $(date +%s) - $(date --date="$(psql -Aqt -h ${POSTGRES_HOST} -c 'select time from block order by id desc limit 1;')" +%s) ))
echo "Date Diff is $DATE_DIFF"

[[ $DATE_DIFF -lt 7200 ]] || { echo "date difference greater than 7200 seconds, so exiting for later retry"; exit 1; }

echo "Block table seems to be on tip or close enough, current time is `date`"




# Check if PostgresDB initialization setup is required:

# Check for Koios Lite
IS_KOIOS_LITE_PG_INIT=`psql -h ${POSTGRES_HOST} -Aqb -t -c "select exists(select 1 from information_schema.tables where table_name = 'control_table' and table_schema = '${KOIOS_LITE_SCHEMA}');"`
echo "IS_KOIOS_LITE_PG_INIT is initially: $IS_KOIOS_LITE_PG_INIT"
if [[ $IS_KOIOS_LITE_PG_INIT == "t" ]]; then
  IS_KOIOS_LITE_PG_INIT=`psql -h ${POSTGRES_HOST} -Aqb -t -c "select exists(select 1 from ${KOIOS_LITE_SCHEMA}.control_table where key = 'postgres_init_timestamp' and last_value is not null)"`
fi

echo "IS_KOIOS_LITE_POSTGRES_INITIALIZED is ${IS_KOIOS_LITE_PG_INIT}"

# Check for Koios Artifacts
IS_KOIOS_ARTIFACTS_PG_INIT=`psql -h ${POSTGRES_HOST} -Aqb -t -c "select exists(select 1 from information_schema.tables where table_name = 'control_table' and table_schema = '${KOIOS_ARTIFACTS_SCHEMA}');"`
echo "IS_KOIOS_ARTIFACTS_PG_INIT is initially: $IS_KOIOS_ARTIFACTS_PG_INIT"
if [[ $IS_KOIOS_ARTIFACTS_PG_INIT == "t" ]]; then
  IS_KOIOS_ARTIFACTS_PG_INIT=`psql -h ${POSTGRES_HOST} -Aqb -t -c "select exists(select 1 from ${KOIOS_ARTIFACTS_SCHEMA}.control_table where key = 'postgres_init_timestamp' and last_value is not null)"`
fi

echo "IS_KOIOS_ARTIFACTS_POSTGRES_INITIALIZED is ${IS_KOIOS_ARTIFACTS_PG_INIT}"

# If it's required, let's run install_postgres.sh and store timestamps into each schema
if [[ $IS_KOIOS_LITE_PG_INIT == "f" || $IS_KOIOS_ARTIFACTS_PG_INIT == "f" ]]; then
  echo "Commencing PG init..."
  ls -al /scripts/lib/install_postgres.sh
  /scripts/lib/install_postgres.sh > foo.out 2>&1
  echo "Done some stuff, curr time is $CURRTIME"
  cat foo.out
  psql -h ${POSTGRES_HOST} -qb -c "INSERT INTO ${KOIOS_LITE_SCHEMA}.control_table (key, last_value) VALUES ('postgres_init_timestamp','${CURRTIME}');"
  psql -h ${POSTGRES_HOST} -qb -c "INSERT INTO ${KOIOS_ARTIFACTS_SCHEMA}.control_table (key, last_value) VALUES ('postgres_init_timestamp','${CURRTIME}');"
  echo "Done postgres init"
fi
