#!/bin/bash

tip=$(psql -h ${POSTGRES_HOST} -qbt -c "select extract(epoch from time)::integer from block order by id desc limit 1;" | xargs)

if [[ $(( $(date +%s) - tip )) -gt 300 ]]; then
  echo "$(date +%F_%H:%M:%S) Skipping as database has not received a new block in past 300 seconds!" && exit 1
fi

echo "$(date +%F_%H:%M:%S) Running asset info cache update..."
psql -h ${POSTGRES_HOST} -qbt -c "SELECT ${KOIOS_LITE_SCHEMA}.asset_info_cache_update();" 1>/dev/null 2>&1
NUMROWS=`psql -h ${POSTGRES_HOST} -t -c "SELECT count(*) from ${KOIOS_LITE_SCHEMA}.asset_info_cache;" 2>/dev/null`
echo "asset info cache table has: $NUMROWS rows"
echo "$(date +%F_%H:%M:%S) Job done!"
