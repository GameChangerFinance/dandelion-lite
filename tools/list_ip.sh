#!/bin/bash

# docker ps -q | xargs docker inspect --format '{{.Name}} - {{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

echo -e "CONTAINER ID\tNAME\t\tIP ADDRESS"
docker ps -q | while read cid; do
    name=$(docker inspect --format '{{.Name}}' "$cid" | sed 's/^\/\(.*\)$/\1/')  # Remove leading slash
    ip=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cid")
    printf "%-15s %-50s %-15s\n" "$cid" "$name" "$ip"
done