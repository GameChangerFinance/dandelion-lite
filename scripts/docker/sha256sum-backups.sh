#!/bin/bash
source .env

backupDir=${BACKUP_DIR} # ends with slash /
[[ -z $backupDir ]] && echo "❌ Missing BACKUP_DIR (with trailing slash). $usage" && exit 1
[[ ! -d $backupDir ]] && echo "❌ BACKUP_DIR does not exist: '$backupDir'" && exit 1

echo "SHA256SUM Report Generator"
echo "Creating a single SHA256SUM.txt of all the files on '${backupDir}'..."

outFile="${backupDir}SHA256SUM.txt"

echo

echo "SHA256SUM Report:" > "$outFile"
sha256sum $backupDir*.* >> "$outFile"
# sha256sum $backupDir*.tar.gz >> "$outFile"
# sha256sum $backupDir*.zip    >> "$outFile"
# sha256sum $backupDir*.rar    >> "$outFile"
echo "-EOF-" >> "$outFile"

echo "Output:"
cat "$outFile"
echo 
echo "✅ Done!"
