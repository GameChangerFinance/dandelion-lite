#!/bin/bash

# Load the environment variables
script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last folder from the path and rename it to KLITE_HOME
SCRIPT_HOME=$(dirname "$script_dir")

GET_IP_V6_SCRIPT=${SCRIPT_HOME}/myaddrdns/update_serverside.sh

echo ${GET_IP_V6_SCRIPT}

(crontab -l 2>/dev/null; echo "*/3 * * * * ${GET_IP_V6_SCRIPT}") | crontab -
