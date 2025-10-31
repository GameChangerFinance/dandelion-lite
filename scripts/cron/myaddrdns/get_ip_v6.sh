#!/bin/bash

# Load the environment variables
script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last folder from the path and rename it to KLITE_HOME
SCRIPT_HOME=$(dirname "$script_dir")

FILENAME=${SCRIPT_HOME}/myaddrdns/my_ip_v6.txt

IP_V6=`curl -s 'https://api64.ipify.org' > ${FILENAME}`

