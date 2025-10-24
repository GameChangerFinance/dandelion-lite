#!/bin/bash

# Exit script on ctrl-c
set -e
trap "exit 130" INT

show_splash_screen(){
  # Clear the screen before displaying UI
  clear
  
  combined_layout1=$(gum style --foreground 121 --align center "$(cat ./scripts/.logo_wizard)")

  combined_layout2=$(gum join --horizontal \
    "$(gum style --bold --align center "${NODE_NAME} | ")" \
    "$(gum style --faint --foreground 229 --align center "${NODE_TICKER}")" \
    "$(gum style --faint --foreground 121 --align center " | ${FULL_DOMAIN_NAME}")")

  combined_layout=$(gum join --vertical \
    "$combined_layout1 " \
    "$combined_layout2")
  
  # Display the combined layout with a border
  gum style \
    --border none \
    --border-foreground 121 \
    --margin "1" \
    --padding "1 2" \
    --background black \
    --foreground 121 \
    "$combined_layout"


}

check_env_file() {
  if [ ! -f ".env" ]; then  # Check if .env does not exist
	show_splash_screen
	action=$(gum choose --height 15 --item.foreground 39 --cursor.foreground 121 "Setup a Cardano Mainnet Network Node" "Setup a Cardano Pre-Production Network Node" )
	case "$action" in
		"Setup a Cardano Mainnet Network Node")
			cp .env.example.mainnet .env  # Copy .env.example to .env
			echo ".env file created from .env.example.mainnet ... please inspect the .env file and adjust variables (e.g. network) accordingly"
			read -p "Press key to continue.." -n1 -s

		;;
		"Setup a Cardano Pre-Production Network Node")
			cp .env.example.preprod .env  # Copy .env.example to .env
			echo ".env file created from .env.example.preprod ... please inspect the .env file and adjust variables (e.g. network) accordingly"
			read -p "Press key to continue.." -n1 -s
		;;
	esac
  fi
}

check_env_file

# Load the environment variables
script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last folder from the path and rename it to KLITE_HOME
KLITE_HOME=$(dirname "$script_dir")
cd "$KLITE_HOME" || exit
source .env

print_hallo(){
  echo "Hallo"
}

update_env_var() {
  local file="$1"
  local var="$2"
  local val="$3"

  if [[ ! -f "$file" ]]; then
    echo "File '$file' does not exist!"
    return 1
  fi

  awk -v var="$var" -v val="$val" '
  BEGIN { updated=0 }
  $0 ~ "^"var"=" {
    print var"="val
    updated=1
    next
  }
  { print }
  END { if (!updated) print var"="val }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

show_splash_screen

echo 'When you have other deployments of the same network type. Please input a different project name.'
PROJ_NAME_INPUT=$(gum input --prompt "name: " --placeholder "${PROJ_NAME}" --prompt.foreground 99 --cursor.foreground 99 --width 50)
if [[ -n "$PROJ_NAME_INPUT" ]]; then
   update_env_var ".env" "PROJ_NAME" ${PROJ_NAME_INPUT}
   PROJ_NAME=$PROJ_NAME_INPUT
fi

show_splash_screen

echo 'When you have other deployments of the same network type. Please input a different port offset.'
PORT_OFFSET_INPUT=$(gum input --prompt "name: " --placeholder "${PORT_OFFSET}" --prompt.foreground 99 --cursor.foreground 99 --width 50)
if [[ -n "$PORT_OFFSET_INPUT" ]]; then
   update_env_var ".env" "PORT_OFFSET" ${PORT_OFFSET_INPUT}
   PORT_OFFSET=$PORT_OFFSET_INPUT
fi

show_splash_screen

echo 'Please input your node name'
NODE_NAME_INPUT=$(gum input --prompt "name: " --placeholder "${NODE_NAME}" --prompt.foreground 99 --cursor.foreground 99 --width 50)
if [[ -n "$NODE_NAME_INPUT" ]]; then
   update_env_var ".env" "NODE_NAME" ${NODE_NAME_INPUT}
   NODE_NAME=$NODE_NAME_INPUT
fi

show_splash_screen

echo 'Please input your node ticker'
NODE_TICKER_INPUT=$(gum input --prompt "ticker: " --placeholder "${NODE_TICKER}" --prompt.foreground 99 --cursor.foreground 99 --width 50)
if [[ -n "$NODE_TICKER_INPUT" ]]; then
  update_env_var ".env" "NODE_TICKER" ${NODE_TICKER_INPUT}
  NODE_TICKER=${NODE_TICKER_INPUT}
fi

show_splash_screen

echo 'Please input your node e-mail'
NODE_EMAIL_INPUT=$(gum input --prompt "e-mail: " --placeholder "${NODE_EMAIL}" --prompt.foreground 99 --cursor.foreground 99 --width 50)
if [[ -n "$NODE_EMAIL_INPUT" ]]; then
  update_env_var ".env" "NODE_EMAIL" ${NODE_EMAIL_INPUT}
  # echo "var ${NODE_EMAIL} "
  # exit
  NODE_EMAIL=${NODE_EMAIL_INPUT}
fi

show_splash_screen

echo 'Press enter to use myaddr (default). If you want to use your own domain enter it'
DOMAIN_INPUT=$(gum input --prompt "Domain: " --placeholder "myaddr.io" --prompt.foreground 99 --cursor.foreground 99 --width 50)

FULL_DOMAIN_NAME=${NODE_TICKER}-dandelion-node.myaddr.io

if [[ $DOMAIN_INPUT ]]; then
    
    DOMAIN=${DOMAIN_INPUT}
else
    DOMAIN='myaddr.io'

    show_splash_screen
    echo "Go to the link below and claim this domain: ${NODE_TICKER}-dandelion-node.myadd.io"
    echo ""
    echo "${NODE_TICKER}-dandelion-node"
    echo ""
    echo 'https://myaddr.tools/claim'
    echo 'Copy the token and paste it in the input below'

    MYADDR_TOKEN_INPUT=$(gum input --prompt "MyAddr token: " --placeholder "${MYADDR_TOKEN}" --prompt.foreground 99 --cursor.foreground 99 --width 50) 
    if [[ -n "$MYADDR_TOKEN_INPUT" ]]; then
      update_env_var ".env" "MYADDR_TOKEN" ${MYADDR_TOKEN_INPUT}
      MYADDR_TOKEN=${MYADDR_TOKEN_INPUT}
    fi
fi    
echo $DOMAIN

show_splash_screen

if gum confirm "Generate ssh key?" --default=true --affirmative "Create" --negative "Skip"; then
    docker compose up -d 
    docker compose exec -it cron /scripts/cron/myaddrdns/certbot.sh
fi

# clear