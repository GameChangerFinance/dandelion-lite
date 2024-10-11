#!/bin/bash

podman compose down
podman volume prune -f
cd ./node-ipc/
rm -rf * 
cd ..
podman compose up -d