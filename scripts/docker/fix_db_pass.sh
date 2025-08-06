#/bin/sh
source .env

backupPassword="backup"
postgresService="postgress"

echo "Setting back your database password..."
docker compose up "$postgresService" -d
docker compose exec -T "$postgresService" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER USER \"$POSTGRES_USER\" WITH PASSWORD '${POSTGRES_PASSWORD}';"
docker compose down

exit 0

