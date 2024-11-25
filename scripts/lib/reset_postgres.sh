#!/bin/bash
# IMPORTANT: run inside postgres container

# Uninstalls all the SQL migrations on /scripts/sql/rpc

# This is useful for example when migrating to a mayor cardano-db-sync release 
# for keeping indexed data intact and let the indexer apply it's own migration files
# without other views and relationships applied on top blocking the upgrade process
# In other terms: it resets db up to cardano-db-sync level, as if only the indexer data exists on db

migrationDir="/scripts/sql/migration/reset-db"
./scripts/lib/postgres_migration.sh $migrationDir

echo -e "SQL scripts have finished processing, following scripts were executed successfully:\n"
cat "$migrationDir/Ok.txt"
echo -e "\n\nThe following errors were encountered during processing:\n"
cat "$migrationDir/NotOk.txt"
echo -e "\n\n"