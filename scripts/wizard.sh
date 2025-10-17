#!/bin/bash

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
  
  gum style --foreground 121 --border-foreground 121 --align center "$(gum join --vertical \
    "$(show_splash_screen)" \
    "$(gum style --align center --width 50 --margin "1 2" --padding "2 2" 'About: ' ' Dandelion Lite Node administration tool. (Based on Koios Lite) ')" \
    "$(gum style --align center --width 50 'https://github.com/koios-official/Lite-Node')")"

  combined_layout1=$(gum style --foreground 121 --align center "$(cat ./scripts/.logo)")

  combined_layout2=$(gum join --horizontal \
    "$(gum style --bold --align center "${NODE_NAME:-'???'} | ")" \
    "$(gum style --faint --foreground 229 --align center "${PROJ_NAME:-'???'}")" \
    "$(gum style --faint --foreground 121 --align center " | - $NAME v$VERSION")")

  combined_layout=$(gum join --vertical \
    "$combined_layout1 " \
    "$combined_layout2")
  
# Name: ${NODE_NAME} | Ticker: ${NODE_TICKER} | Domain: ${FULL_DOMAIN_NAME}
# ")
  # Display the combined layout with a border
  gum style \
    --border none \
    --border-foreground 121 \
    --margin "1" \
    --padding "1 2" \
    --background black \
    --foreground 121 \
    "$layout"


}

show_splash_screen

echo 'Please input your ticker and the name you want to use '
NODE_NAME=$(gum input --prompt "name: " --placeholder "XZibit" --prompt.foreground 99 --cursor.foreground 99 --width 50)
update_env_var ".env" "NODE_NAME" ${NODE_NAME}

show_splash_screen

NODE_TICKER=$(gum input --prompt "ticker: " --placeholder "XYZ" --prompt.foreground 99 --cursor.foreground 99 --width 50)
update_env_var ".env" "NODE_TICKER" ${NODE_TICKER}
FULL_DOMAIN_NAME=${NODE_TICKER}-dandelion-node.myaddr.io

show_splash_screen
echo 'Please input your domain. We commonly use a service called myaddr in that case press enter'
DOMAIN_INPUT=$(gum input --prompt "Domain: " --placeholder "myaddr.io" --prompt.foreground 99 --cursor.foreground 99 --width 50)

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

    MYADDR_TOKEN=$(gum input --prompt "MyAddr token: " --placeholder "k1t7gq4wzv9mj2r8n0hxb3sy6cdufp5aoliei7q2trwz8km9vcsxjd4n1pgu0f" --prompt.foreground 99 --cursor.foreground 99 --width 50) 
    update_env_var ".env" "MYADDR_TOKEN" ${MYADDR_TOKEN}
fi    
echo $DOMAIN

show_splash_screen

if gum confirm "Generate ssh key?" --default=true --affirmative "Create" --negative "Skip"; then
    docker compose exec -it cron /scripts/cron/myaddrdns/certbot.sh
fi

# clear