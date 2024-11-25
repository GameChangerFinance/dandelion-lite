#!/bin/sh

volumeName=$1
fileName=$2
backupDir=$3

if [ -z "$volumeName" ]; then
  echo "Missing docker compose volume name (with project name prefix!)"
  exit 1
fi

if [ -z "$fileName" ]; then
  echo "Missing backup filename (without file extensions!)"
  exit 1
fi

if [ -z "$backupDir" ]; then
  echo "Missing backup directory path (with last slash)"
  exit 1
fi

sourceVolumeName="${volumeName}"
exportFileName="${fileName}.tar.gz"

echo "Exporting volume '$sourceVolumeName' into backup file '${backupDir}$exportFileName' ..."

# Ensure the backup directory exists
mkdir -p "$backupDir"

# Ensure os image is cached locally prior starting to avoid random errors due to bad internet connection
docker pull alpine:3.20.1

# As making a solid backup is mandatory, lets delete a previous file if any:
if [ -f "${backupDir}${exportFileName}" ]; then
  rm "${backupDir}${exportFileName}" && echo "Old file deleted."
fi

# Run the container with Podman
podman run --rm \
        --mount type=volume,source=${sourceVolumeName},target=/volume \
        -v ${backupDir}:/backup \
        alpine:3.20.1 \
        sh -c "apk update && apk add pigz && tar cvf - /volume | pigz > /backup/${exportFileName}"

# Check if the backup file was created successfully
if [ -f "${backupDir}${exportFileName}" ]; then
  ls -alh "${backupDir}${exportFileName}" | awk '{print $5, $9}'
  echo "Done"
else
  echo "Failed to create the backup file."
  exit 1
fi

exit 0
