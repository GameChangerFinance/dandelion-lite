#!/bin/bash
# IMPORTANT: run inside postgres container

# Installs all the SQL migrations on /scripts/sql/rpc
migrationDir="/scripts/sql/rpc"
./scripts/lib/postgres_migration.sh $migrationDir

echo -e "SQL scripts have finished processing, following scripts were executed successfully:\n"
cat "$migrationDir/Ok.txt"
echo -e "\n\nThe following errors were encountered during processing:\n"
cat "$migrationDir/NotOk.txt"
echo -e "\n\n"