#!/bin/bash

if [ -d ".venv" ]; then
    echo ".venv exists"
else
    echo ".venv does not exist"
    python3 -m venv .venv
    # source .venv/bin/activate
    .venv/bin/pip3 install -r ./scripts/urwid/requirements.txt

    if ! sudo apt update && sudo apt install -y wl-clipboard; then return 1; fi
fi

./scripts/urwid/wizard.py




