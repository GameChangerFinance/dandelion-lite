#/bin/sh

projectName=$1
backupDir=$2

[[ -z $projectName ]] && echo "Missing docker compose project name (actually only a prefix is required)" && exit 1
[[ -z $backupDir ]] && echo "Missing directory path with the stored backup files (with last slash)" && exit 1

echo "Restoring project '$projectName'..."
echo

volumeNames=$(docker volume ls -q)

echo "About to try restoring all these volumes with these backup files (${backupDir}<volume_name_without_project_name.tar.gz>):"

for volumeName in $volumeNames; do
    if [[ $volumeName == "$projectName"* ]]; then   # True if $volumeName starts with $projectName.
        fileName=$(echo $volumeName | sed "s/^${projectName}//")
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
	fileName=$(echo $volumeName | sed "s/^${projectName}//")
	echo $fileName
    	./scripts/docker/restore-volume.sh "${volumeName}" "${fileName}" "${backupDir}">> full-restore.log 2>&1
	ls -alh "${backupDir}${fileName}.tar.gz" | awk '{print $5, $9}'
	#read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
	echo
    fi
done

exit 0

