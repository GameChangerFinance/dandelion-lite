#!/usr/bin/env bash

source ".env"

host="localhost"

echo "cardano-graphql: http://$host:$(expr $CARDANO_GRAPHQL_SERVER_PORT + 0)"
echo "koios:	 	 http://$host:$(expr $HAPROXY_PORT + 0)"
echo "postgrest:	 http://$host:$(expr $HAPROXY_PORT + 0)"
echo "ogmios:	 	 ws://$host:$(expr $CARDANO_OGMIOS_PORT + 0)"
echo "token-registry:	 http://$host:$(expr $DBLESS_CARDANO_TOKEN_REGISTRY_PORT + 0)"

