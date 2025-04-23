#!/bin/bash

docker compose down

docker volume rm dandolite-local_unimatrix-data dandolite-local_dbless-cardano-token-registry-data dandolite-local_pgadmin-data dandolite-local_postgresdb dandolite-local_unimatrix-data

docker compose up -d

sudo chown -R maarten:maarten node-ipc cluster
