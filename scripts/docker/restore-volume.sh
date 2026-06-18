#/bin/sh

volumeName=$1
fileName=$2
backupDir=$3

[[ -z $volumeName ]] && echo "❌ Missing docker compose volume name (with project name prefix!)" && exit 1
[[ -z $fileName ]] && echo "❌ Missing backup filename (without file extensions!)" && exit 1
[[ -z $backupDir ]] && echo "❌ Missing backup directory path (with last slash)" && exit 1

targetVolumeName="${volumeName}"
backupFileName="${fileName}.tar.gz"

echo "ℹ️ Restoring volume '$targetVolumeName' from backup file '${backupDir}$backupFileName' ..."

ls -alh "${backupDir}${backupFileName}" | awk '{print $5, $9}'

docker run --rm \
  -v ${backupDir}:/backup \
  -v "$targetVolumeName":/volume \
	  alpine \
	  bin/sh -c "rm -rfv /volume/* && tar xzvf /backup/${backupFileName} -C /volume --strip 1"

echo "✅ Volume restore completed."

#bin/sh -c "ls /volume && rm -rfv /volume/* && tar xzvf /backup/${backupFileName} -C /volume --strip 1 && ls /volume"
