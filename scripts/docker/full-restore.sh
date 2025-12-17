#!/bin/bash

# Load the environment variables
script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last folder from the path and rename it to KLITE_HOME
DLITE_HOME=$(dirname "$(dirname -- "$script_dir")")

cd "$DLITE_HOME" || exit
source .env

projectName=${1:-"$PROJ_NAME"}
backupDir=${2:-"$BACKUP_DIR"}
postgresService="postgress"

[[ -z $projectName ]] && echo "Missing docker compose project name (actually only a prefix is required)" && exit 1
[[ -z $backupDir ]] && echo "Missing directory path with the stored backup files (with last slash)" && exit 1

echo "Restoring project '$projectName'..."
echo

volumeNames=$(docker volume ls -q)

echo "About to try restoring all these volumes with these backup files (${backupDir}<volume_name_without_project_name.tar.gz>):"

for volumeName in $volumeNames; do
    if [[ $volumeName == "$projectName"* ]]; then   # True if $volumeName starts with $projectName.
        fileName=$(echo $volumeName | sed "s/^${projectName}_//")
		echo $fileName
		echo "${volumeName}: ${fileName}.tar.gz"
		ls -alh "${backupDir}${fileName}.tar.gz" | awk '{print $5, $9}'
    fi
done
echo

echo "Warning: all containers will be turned off AND ALL VOLUME DATA WILL BE REPLACED !"

read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
echo
read -p "Last chance: Press key to CONFIRM.. (Ctrl + C to abort)" -n1 -s
echo
docker compose down
echo
for volumeName in $volumeNames; do
    if [[ $volumeName == "$projectName"* ]]; then   # True if $volumeName starts with $projectName.
	fileName=$(echo $volumeName | sed "s/^${projectName}_//")
	echo $fileName
    	./scripts/docker/restore-volume.sh "${volumeName}" "${fileName}" "${backupDir}">> full-restore.log 2>&1
	ls -alh "${backupDir}${fileName}.tar.gz" | awk '{print $5, $9}'
	#read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
	echo
    fi
done

echo "Setting your custom database password as backups are shipped with a dummy one..."
docker compose up "$postgresService" -d
docker compose exec -T "$postgresService" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER USER \"$POSTGRES_USER\" WITH PASSWORD '${POSTGRES_PASSWORD}';"
docker compose down

exit 0

