#!/bin/bash
set -x

docker compose exec -it postgress psql -U dandelion_user -d dandelion_lite -t -A -c "$(cat stats_call_time.sql)" > stats_call_time.json
docker compose exec -it postgress psql -U dandelion_user -d dandelion_lite -t -A -c "$(cat stats_block_read.sql)" > stats_block_read.json


