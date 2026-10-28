#/bin/bash

source .env

echo "IMPORTANT: install ngrok and connect your account before using this feature: https://ngrok.com/docs/share-localhost/quickstart"
echo "ℹ️ Use this interactive tunnel for temporary access during development and testing."
echo
echo "Initiallizing tunneling ... "
echo

ngrok http $(expr $HAPROXY_PORT + 0) | cat &
sleep 5

tunnelHost=$(curl http://127.0.0.1:4040/api/tunnels --silent | jq '.tunnels | .[] | .public_url' | sed -e 's/^"//' -e 's/"$//')

[[ -z ${tunnelHost} ]] && echo "command took more time than expected or simply failed. Aborting..." && exit 1

echo "Tunnel URL:		$tunnelHost"
echo
echo "Now you can visit it on browser to monitor node status, or use these APIs:"
echo "   ogmios: 		${tunnelHost}/ogmios/"
echo "   cardano-graphql:     ${tunnelHost}/cardano-graphql/"
echo "   koios/koios-lite:    ${tunnelHost}/koios/"
echo "   token-registry:      ${tunnelHost}/token-registry/"
echo "   dandelion-postgrest: ${tunnelHost}/postgrest/"
echo "   cardano-sql:         ${tunnelHost}/cardano-sql/"
echo

read -p "Press any key to shutdown ngrok tunneling"

killall -9 ngrok

echo "Tunnel closed."

