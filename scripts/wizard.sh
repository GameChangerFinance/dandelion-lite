#!/bin/bash

script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last folder from the path and rename it to KLITE_HOME
KLITE_HOME=$(dirname "$script_dir")
cd "$KLITE_HOME" || exit
source .env

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

# Example usage:

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

show_splash_screen

echo 'Please input your node name'
echo "node name: ${NODE_NAME}"
NODE_NAME=$(gum input --prompt "name: " --placeholder "${NODE_NAME}" --prompt.foreground 99 --cursor.foreground 99 --width 50)

if [[ -n "$NODE_NAME" ]]; then
   update_env_var ".env" "NODE_NAME" ${NODE_NAME}
fi


show_splash_screen

echo 'Please input your node ticker'
NODE_TICKER=$(gum input --prompt "ticker: " --placeholder "${NODE_TICKER}" --prompt.foreground 99 --cursor.foreground 99 --width 50)
if [[ -n "$NODE_TICKER" ]]; then
  update_env_var ".env" "NODE_TICKER" ${NODE_TICKER}
fi

show_splash_screen

echo 'Please input your node e-mail'
NODE_EMAIL=$(gum input --prompt "e-mail: " --placeholder "${NODE_EMAIL}" --prompt.foreground 99 --cursor.foreground 99 --width 50)
if [[ -n "$NODE_EMAIL" ]]; then
  update_env_var ".env" "NODE_EMAIL" ${NODE_EMAIL}
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

    MYADDR_TOKEN=$(gum input --prompt "MyAddr token: " --placeholder "${MYADDR_TOKEN}" --prompt.foreground 99 --cursor.foreground 99 --width 50) 
    if [[ -n "$MYADDR_TOKEN" ]]; then
      update_env_var ".env" "MYADDR_TOKEN" ${MYADDR_TOKEN}
    fi
fi    
echo $DOMAIN

show_splash_screen

if gum confirm "Generate ssh key?" --default=true --affirmative "Create" --negative "Skip"; then
    docker compose exec -it cron /scripts/cron/myaddrdns/certbot.sh
fi

# clear