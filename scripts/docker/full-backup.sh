#/bin/sh

projectName=$1
backupDir=$2

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

exit 0

