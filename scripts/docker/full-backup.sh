#/bin/sh
source .env

projectName=$1
backupDir=$2
backupPassword="backup"
postgresService="postgress"

[[ -z $projectName ]] && echo "Missing docker compose project name (actually only a prefix is required)" && exit 1
[[ -z $backupDir ]] && echo "Missing directory path for storing backup files (with last slash)" && exit 1

echo "Making a backup of project '$projectName'..."
echo

volumeNames=$(docker volume ls -q)

echo "About to backup all these volumes into these backup files (${backupDir}<volume_name_without_project_name.tar.gz>):"

for volumeName in $volumeNames; do
    if [[ $volumeName == "$projectName"* ]]; then   # True if $volumeName starts with a projectName.
        fileName=$(echo $volumeName | sed "s/^${projectName}//")
        echo "$volumeName: ${fileName}.tar.gz"
    fi
done
echo
echo "Warning: all containers will be turned off to proceed with a clean state !"

read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
echo

docker compose down

echo "Setting a dummy database password '$backupPassword' for safe backup sharing..."
docker compose up "$postgresService" -d 
docker compose exec -it "$postgresService" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER USER \"$POSTGRES_USER\" WITH PASSWORD '$backupPassword';"
docker compose down

# Perform all the backups
for volumeName in $volumeNames; do
    if [[ $volumeName == "$projectName"* ]]; then   # True if $volumeName starts with a projectName.
	fileName=$(echo $volumeName | sed "s/^${projectName}//")
	echo "Creating '${fileName}.tar.gz'..."
    	./scripts/docker/backup-volume.sh "${volumeName}" "${fileName}" "${backupDir}" >> full-backup.log 2>&1
	ls -alh "${backupDir}${fileName}.tar.gz" | awk '{print $5, $9}'
	#read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
	echo
    fi
done

echo "Setting back your database password..."
docker compose up "$postgresService" -d
docker compose exec -T "$postgresService" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER USER \"$POSTGRES_USER\" WITH PASSWORD '${POSTGRES_PASSWORD}';"
docker compose down

./scripts/docker/sha256sum-backups.sh "${backupDir}"

exit 0

