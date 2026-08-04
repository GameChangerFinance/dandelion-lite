#!/usr/bin/env bash
# Example usage: ./full-backup-sync.sh "https://your-dando-node/backups/" myproject_ /tmp/backups/ backup mysecurepass

set -euo pipefail

remoteBackupURL=${1:-}
projectName=${2:-}
backupDir=${3:-}
remoteBackupUser=${4:-}
remoteBackupPassword=${5:-}

usage='Example usage: ./scripts/docker/full-backup-sync.sh "https://your-dando-node/backups/" myproject_ /tmp/backups/ backup mysecurepass'
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
REPO_ROOT=$(dirname "$(dirname -- "$script_dir")")

[[ -z $remoteBackupURL ]] && echo "❌ Missing remote backup files URL (with trailing slash). $usage" >&2 && exit 1
[[ -z $projectName ]] && echo "❌ Missing docker compose project name (prefix only is fine). $usage" >&2 && exit 1
[[ -z $backupDir ]] && echo "❌ Missing directory path for storing backup files (with trailing slash). $usage" >&2 && exit 1

if [[ -n $remoteBackupUser && -z $remoteBackupPassword ]] || [[ -z $remoteBackupUser && -n $remoteBackupPassword ]]; then
  echo "❌ Missing remote backup credentials: username and password must be provided together, or both left empty for unauthenticated downloads. $usage" >&2
  exit 1
fi

command -v aria2c >/dev/null 2>&1 || { echo "❌ Missing aria2c command. Install dependencies with ./scripts/dandoman.sh before downloading remote backups." >&2; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo "❌ Missing md5sum command. Install dependencies with ./scripts/dandoman.sh before downloading remote backups." >&2; exit 1; }

cd "$REPO_ROOT" || exit 1
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

remoteBackupURL="${remoteBackupURL%/}/"
backupDir="${backupDir%/}/"
use_auth=0

if [[ -z $remoteBackupUser || -z $remoteBackupPassword ]]; then
  echo "⚠️ Warning: no credentials provided, will attempt unauthenticated downloads"
else
  use_auth=1
fi

tmpDir=$(mktemp -d)
trap 'rm -rf "$tmpDir"' EXIT

download_metadata() {
  local name=$1
  local dest=$2
  local aria_args=(
    --allow-overwrite=true
    --auto-file-renaming=false
    --check-certificate=false
    --dir="$tmpDir"
    --out="$dest"
  )

  if [[ $use_auth -eq 1 ]]; then
    aria_args+=(--http-user="$remoteBackupUser" --http-passwd="$remoteBackupPassword")
  fi

  aria2c "${aria_args[@]}" "${remoteBackupURL}${name}" >/dev/null
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

parse_ready() {
  local file=$1
  local line key value
  declare -gA ready=()
  declare -A seen=()

  while IFS= read -r line || [[ -n $line ]]; do
    line=$(trim "$line")
    [[ -z $line || ${line:0:1} == "#" ]] && continue
    [[ $line == *=* ]] || { echo "❌ Invalid READY metadata line (expected KEY=value): $line" >&2; return 1; }

    key=$(trim "${line%%=*}")
    value=$(trim "${line#*=}")
    [[ $key =~ ^[A-Z0-9_]+$ ]] || { echo "❌ Invalid READY metadata key '$key' (expected uppercase snake case like NETWORK)." >&2; return 1; }
    [[ -z ${seen[$key]:-} ]] || { echo "❌ Duplicate READY metadata key '$key'." >&2; return 1; }

    seen[$key]=1
    ready[$key]=$value
  done < "$file"

  for key in DLT NETWORK CARDANO_NODE_VERSION CARDANO_DB_SYNC_VERSION UPDATED_AT; do
    [[ -n ${ready[$key]+x} ]] || { echo "❌ Missing READY metadata key '$key'." >&2; return 1; }
  done
}

require_local_env() {
  local name=$1
  local value=${!name:-}
  if [[ -z $value ]]; then
    echo "❌ Missing local environment variable '$name' on .env file." >&2
    exit 1
  fi
}

warn_version_mismatch() {
  local key=$1
  local localValue=${!key:-}
  local remoteValue=${ready[$key]:-}

  [[ $localValue == "$remoteValue" ]] && return 0
  
  echo "⚠️ WARNING:" >&2
  echo "⚠️ Incoming remote backup has $key='$remoteValue' but local .env has $key='$localValue'." >&2
  echo "⚠️ This can be harmful unless this is an intentional upgrade workflow." >&2
  echo "" >&2
  return 1
}

confirm_version_mismatches() {
  local mismatched=0

  warn_version_mismatch CARDANO_NODE_VERSION || mismatched=1
  warn_version_mismatch CARDANO_DB_SYNC_VERSION || mismatched=1

  [[ $mismatched -eq 0 ]] && return 0
  [[ ${ALLOW_BACKUP_VERSION_MISMATCH:-} == "1" ]] && return 0

  if [[ -t 0 ]]; then
    read -r -p "Type OK to sync this backup set anyway: " answer
    [[ $answer == "OK" ]] && return 0
  fi

  echo "❌ Aborting because backup versions differ. Type OK on interactive runs or set ALLOW_BACKUP_VERSION_MISMATCH=1 for planned non-interactive upgrade syncs." >&2
  exit 1
}

manifest_hash_for() {
  local manifestFile=$1
  local wanted=$2
  local hashPattern='^[0-9a-fA-F]{64}$'

  if [[ $manifestFile == *MD5SUMS ]]; then
    hashPattern='^[0-9a-fA-F]{32}$'
  fi

  awk -v wanted="$wanted" '
    $1 ~ hashPattern {
      name=$0
      sub(/^[0-9a-fA-F]+[[:space:]][[:space:]]?[*]?/, "", name)
      if (name == wanted || name == "./" wanted) {
        print $1
        exit
      }
    }
  ' hashPattern="$hashPattern" "$manifestFile"
}

file_matches_hash() {
  local file=$1
  local hash=$2
  local commandName=$3

  [[ -f $file ]] || return 1
  printf '%s  %s\n' "$hash" "$file" | "$commandName" -c --status -
}

compare_final_sha256_payloads() {
  local fileName remoteHash localHash

  while IFS= read -r fileName; do
    [[ -z $fileName ]] && continue
    remoteHash=$(manifest_hash_for "$tmpDir/SHA256SUMS" "$fileName")
    localHash=$(manifest_hash_for "${backupDir}SHA256SUMS" "$fileName")

    [[ -n $remoteHash ]] || { echo "❌ Missing remote SHA256SUMS entry for '$fileName'." >&2; return 1; }
    [[ -n $localHash ]] || { echo "❌ Missing local SHA256SUMS entry for '$fileName'." >&2; return 1; }

    if [[ $remoteHash != "$localHash" ]]; then
      echo "❌ SHA256SUMS mismatch for '$fileName'. Remote has '$remoteHash' but local generated '$localHash'." >&2
      return 1
    fi
  done < "$tmpDir/expected-backup-files"
}

ensure_compose_volumes() {
  local volume full_name

  if ! (cd "$REPO_ROOT" && docker compose config --volumes) >"$tmpDir/compose-volumes" 2>"$tmpDir/compose-volumes.err"; then
    echo "❌ Could not read compose volumes with 'docker compose config --volumes'." >&2
    cat "$tmpDir/compose-volumes.err" >&2 || true
    return 1
  fi

  while IFS= read -r volume; do
    [[ -z "$volume" ]] && continue
    full_name="${projectName}${volume}"
    if ! docker volume inspect "$full_name" >/dev/null 2>&1; then
      echo "ℹ️ Creating missing volume: ${full_name}"
      docker volume create "$full_name" >/dev/null
    fi
  done < "$tmpDir/compose-volumes"
}

echo
echo "ℹ️ Checking remote backup metadata..."
download_metadata READY READY || { echo "❌ Missing remote READY metadata file at '${remoteBackupURL}READY'. Remote backup repository is not ready or not reachable." >&2; exit 1; }
download_metadata MD5SUMS MD5SUMS || { echo "❌ Missing remote MD5SUMS fast-checks file at '${remoteBackupURL}MD5SUMS'. Remote backup repository is not ready or not reachable." >&2; exit 1; }
download_metadata SHA256SUMS SHA256SUMS || { echo "❌ Missing remote SHA256SUMS checksums file at '${remoteBackupURL}SHA256SUMS'. Remote backup repository is not ready or not reachable." >&2; exit 1; }
parse_ready "$tmpDir/READY"

for key in DLT NETWORK CARDANO_NODE_VERSION CARDANO_DB_SYNC_VERSION; do
  require_local_env "$key"
done

if [[ ${ready[DLT]} != "$DLT" ]]; then
  echo "❌ DLT mismatch on READY metadata. Incoming remote backup has DLT='${ready[DLT]}' but local .env has DLT='$DLT'." >&2
  exit 1
fi

if [[ ${ready[NETWORK]} != "$NETWORK" ]]; then
  echo "❌ NETWORK mismatch on READY metadata. Incoming remote backup has NETWORK='${ready[NETWORK]}' but local .env has NETWORK='$NETWORK'." >&2
  exit 1
fi

confirm_version_mismatches

echo "ℹ️ Ensuring Docker Compose volumes exist before downloading backups..."
ensure_compose_volumes

mkdir -p "$backupDir"
rm -f "${backupDir}READY" "${backupDir}MD5SUMS" "${backupDir}SHA256SUMS"

echo "ℹ️ Downloading backups from '$remoteBackupURL' into local dir '$backupDir'..."
# echo "ℹ️ Will attempt to download backup files into: ${backupDir}<volume_name_without_prefix>.tar.gz"
echo

mapfile -t volumeNames < <(docker volume ls -q | sort)
: > "$tmpDir/expected-backup-files"

for volumeName in "${volumeNames[@]}"; do
  if [[ $volumeName == "$projectName"* ]]; then
    fileName=${volumeName#"$projectName"}
    backupFileName="${fileName}.tar.gz"
    targetPath="${backupDir}${backupFileName}"
    expectedMd5=$(manifest_hash_for "$tmpDir/MD5SUMS" "$backupFileName")

    [[ -z $expectedMd5 ]] && echo "❌ Missing MD5SUMS entry for expected backup file '$backupFileName'." >&2 && exit 1
    echo "$backupFileName" >> "$tmpDir/expected-backup-files"

    if file_matches_hash "$targetPath" "$expectedMd5" md5sum; then
      echo "✅ Local file already matches MD5SUMS fast-check: $backupFileName"
      echo
      continue
    fi

    if [[ -f $targetPath ]]; then
      echo "ℹ️ Local file exists but does not match MD5SUMS fast-check; trying aria2 resume before overwrite."
    fi

    "$script_dir/backup-sync.sh" "$remoteBackupURL" "$volumeName" "$fileName" "$backupDir" "$remoteBackupUser" "$remoteBackupPassword"

    if ! file_matches_hash "$targetPath" "$expectedMd5" md5sum; then
      echo "⚠️ Resume/update completed but did not produce the expected MD5 fast-check; removing only '$targetPath' and retrying once." >&2
      rm -f "$targetPath" "${targetPath}.aria2"
      "$script_dir/backup-sync.sh" "$remoteBackupURL" "$volumeName" "$fileName" "$backupDir" "$remoteBackupUser" "$remoteBackupPassword"
      file_matches_hash "$targetPath" "$expectedMd5" md5sum || {
        echo "❌ Downloaded backup file failed MD5SUMS fast-check: $targetPath" >&2
        exit 1
      }
    fi

    echo
  fi
done

echo "ℹ️ Creating local READY, MD5SUMS and SHA256SUMS files..."
READY_SOURCE_FILE="$tmpDir/READY" "$script_dir/create-backup-checksum.sh" "$backupDir"

echo "ℹ️ Verifying generated local SHA256SUMS against remote SHA256SUMS..."
compare_final_sha256_payloads || {
  mkdir -p "${backupDir}old"
  mv -f "${backupDir}READY" "${backupDir}old/READY"
  echo "⚠️ Final SHA256SUMS verification failed because local files do not match the remote hashes. READY file was moved to '${backupDir}old/READY' so other operators do not treat this published backup set as ready yet." >&2  
  echo "ℹ️ Re-run '${script_dir}full-backup-sync.sh' to sync with remote again, this will create a READY file matching remote docker image versions" >&2    
  echo "ℹ️ Run '${script_dir}create-backup-checksum.sh' to create the READY file matching your local backup files and docker image versions" >&2    
  exit 1
}

echo
echo "ℹ️ Current backup files in $backupDir:"
echo

for volumeName in "${volumeNames[@]}"; do
  if [[ $volumeName == "$projectName"* ]]; then
    fileName=${volumeName#"$projectName"}
    path="${backupDir}${fileName}.tar.gz"
    if [[ -f $path ]]; then
      echo "  $fileName.tar.gz - $(ls -lh "$path" | awk '{print $5}')"
    else
      echo "  ❌ Missing: $fileName.tar.gz"
    fi
  fi
done

echo
echo "✅ All done."
