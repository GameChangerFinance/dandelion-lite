#!/bin/bash


show_header () {

clear
gum style --border=rounded --padding="0 2" --align=center --foreground=212 --border-foreground=99 "
 _    _ _                      _ 
| |  | (_)                    | |
| |  | |_ __________ _ _ __ __| |
| |/\| | |_  /_  / _\` | '__/ _\` |
\  /\  / |/ / / / (_| | | | (_| |
 \/  \/|_/___/___\__,_|_|  \__,_|
${FULL_DOMAIN_NAME}


"

}

show_header

echo 'Please input your ticker and the name you want to use '
NODE_TICKER=$(gum input --prompt "ticker: " --placeholder "XYZ" --prompt.foreground 99 --cursor.foreground 99 --width 50)
NAME=$(gum input --prompt "name: " --placeholder "XZibit" --prompt.foreground 99 --cursor.foreground 99 --width 50)
FULL_DOMAIN_NAME=${NODE_TICKER}-dandelion-node.myaddr.io

show_header
echo 'Please input your domain. We commonly use a service called myaddr in that case press enter'
DOMAIN_INPUT=$(gum input --prompt "Domain: " --placeholder "myaddr.io" --prompt.foreground 99 --cursor.foreground 99 --width 50)

if [[ $DOMAIN_INPUT ]]; then
    
    DOMAIN=${DOMAIN_INPUT}
else
    DOMAIN='myaddr.io'

    show_header
    echo "Go to the link below and claim this domain: ${NODE_TICKER}-dandelion-node.myadd.io"
    echo 'https://myaddr.tools/claim'
    echo 'Copy the token and paste it in the input below'

    MYADDR_TOKEN=$(gum input --prompt "MyAddr token: " --placeholder "k1t7gq4wzv9mj2r8n0hxb3sy6cdufp5aoliei7q2trwz8km9vcsxjd4n1pgu0f" --prompt.foreground 99 --cursor.foreground 99 --width 50) 
fi    
echo $DOMAIN



show_header
gum confirm "Generate ssh key?" --default=true --affirmative "Create" --negative "Skip"

clear