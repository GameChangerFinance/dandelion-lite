#!/bin/bash

# Get the directory of the current script
# Load the environment variables
script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last 2 folders from the path and rename it to DLITE_HOME
DLITE_HOME=$(dirname -- "$script_dir")

cd "$DLITE_HOME" || exit
echo $DLITE_HOME

# Check for virtual environment
if [ -d ".venv" ]; then
    echo ".venv exists"
else
    echo ".venv does not exist"
    python3 -m venv .venv
    # Activate the venv (optional here)
    .venv/bin/pip3 install -r "scripts/wizard/requirements.txt"

    if ! sudo apt update && sudo apt install -y wl-clipboard aria2; then
        exit 1
    fi
fi

# Run the Python script
./scripts/wizard/wizard.py





