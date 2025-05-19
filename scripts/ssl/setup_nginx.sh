#!/bin/bash

sudo apt update
sudo apt install nginx certbot python3-certbot-nginx -y

source ../../.env

echo ${DUCKDNS_DOMAINS}.duckdns.org

DOMAIN=${DUCKDNS_DOMAINS}.duckdns.org

cat <<EOF | sudo tee /etc/nginx/sites-available/dandelion  > /dev/null
server {
    listen 80;
    listen [::]:80;

    server_name preprod.${DOMAIN};

    location / {
        proxy_pass http://localhost:3081/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

}

server {
    listen 80;
    listen [::]:80;

    server_name mainnet.${DOMAIN};

    location / {
        proxy_pass http://localhost:3080/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

}
EOF


sudo ln -sf /etc/nginx/sites-available/dandelion /etc/nginx/sites-enabled/

sudo nginx -t && sudo systemctl reload nginx

sudo certbot --nginx
