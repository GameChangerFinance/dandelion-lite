#!/bin/bash
source ../.env
docker compose exec -it postgress psql -U  ${POSTGRES_USER} -d ${POSTGRES_DB}
