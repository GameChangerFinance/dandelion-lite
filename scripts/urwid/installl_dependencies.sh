#!/bin/bash

if ! sudo apt update && sudo apt install -y gpg curl gawk; then return 1; fi

python -m venv .venv
source .venv/bin/activate
pip install -r ./scripts/urwid/requirements.txt
