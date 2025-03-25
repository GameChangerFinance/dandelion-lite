#!/bin/bash
set -x

docker compose exec -it postgress psql -U dandelion_user dandelion_lite