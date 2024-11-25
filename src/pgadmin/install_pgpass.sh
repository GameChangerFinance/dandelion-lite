#!/bin/sh
set -x
EMAIL_SANITIZED="$(echo $PGADMIN_DEFAULT_EMAIL | tr @ _)"
echo "Creating storage for default account: ${EMAIL_SANITIZED}" ;
mkdir -p /var/lib/pgadmin/storage/${EMAIL_SANITIZED};
PGADMIN_SERVER_JSON_FILE=/pgadmin4/servers.json ;
PGADMIN_PASSWORD_FILE=/var/lib/pgadmin/storage/${EMAIL_SANITIZED}/pgpass ;
rm -rf $PGADMIN_PASSWORD_FILE ;
rm -rf $PGADMIN_SERVER_JSON_FILE ;
echo "*:*:*:${POSTGRES_USER}:${POSTGRES_PASSWORD}" > $PGADMIN_PASSWORD_FILE ;
echo "{\"Servers\": {\"1\": { \"Group\": \"Servers\", \"Name\": \"${NETWORK}\", \"Host\": \"postgress\", \"Port\": 5432, \"MaintenanceDB\": \"${POSTGRES_DB}\",  \"Username\": \"${POSTGRES_USER}\",  \"ConnectionParameters\": {  \"sslmode\": \"prefer\", \"connect_timeout\": 10, \"passfile\": \"/pgpass\" } }}}" > $PGADMIN_SERVER_JSON_FILE ;
chmod 600 $PGADMIN_PASSWORD_FILE ;
chown pgadmin:root $PGADMIN_PASSWORD_FILE ;
chmod 600 $PGADMIN_SERVER_JSON_FILE ;
chown pgadmin:root $PGADMIN_SERVER_JSON_FILE ;
echo 'Default Config file' ;
cat $PGADMIN_SERVER_JSON_FILE ;
PGADMIN_SERVER_JSON_FILE=$PGADMIN_SERVER_JSON_FILE