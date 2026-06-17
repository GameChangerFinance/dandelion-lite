# Dandelion Lite Docker Scripts

This directory contains the Docker and Podman helper scripts used by `scripts/dandoman.sh` and by operators running maintenance tasks directly.

The scripts are intentionally small shell entrypoints. Keep their public call signatures stable because they are used by both humans and wrapper scripts.

## Backup Files

Volume backup files use this naming convention:

```text
<volume_name_without_project_prefix>.tar.gz
```

For example, a Docker volume named `dandolite-preprod_node-db` is stored as:

```text
node-db.tar.gz
```

Backup directories may be passed with or without a trailing slash.

## Backup Metadata

Published backup sets must include these files beside the `.tar.gz` archives:

```text
READY
SHA256SUMS
```

`READY` is plain `key=value` metadata. Required keys are:

```env
DLT=cardano
NETWORK=preprod
CARDANO_NODE_VERSION=11.0.1
CARDANO_DB_SYNC_VERSION=13.7.1.0
UPDATED_AT=2026-06-17T00:00:00Z
```

`READY` parsing is position-agnostic. Key order may vary, blank lines and comment lines are ignored, and required keys must appear exactly once.

`SHA256SUMS` uses the standard `sha256sum` format:

```text
<sha256-hex>  <filename>
```

It can be checked directly:

```sh
cd /path/to/backups
sha256sum -c SHA256SUMS
```

## Sync Safety

`full-backup-sync.sh` treats remote `READY` and `SHA256SUMS` as the authority before downloading payload files.

Validation behavior:

- missing remote `READY`: fail before payload downloads
- missing remote `SHA256SUMS`: fail before payload downloads
- remote `DLT` mismatch: fail with incoming and local values
- remote `NETWORK` mismatch: fail with incoming and local values
- `CARDANO_NODE_VERSION` mismatch: warn with incoming and local values
- `CARDANO_DB_SYNC_VERSION` mismatch: warn with incoming and local values

Version mismatches require explicit operator intent. In an interactive shell, type `OK` when prompted. For planned non-interactive upgrade flows, set `ALLOW_BACKUP_VERSION_MISMATCH=1` only for that command invocation.

The payload downloader uses `aria2c` with file auto-renaming disabled. It writes to the final target filename and must not create duplicate backup files such as `.1`, `.2`, or `.3`.

If a local file already matches `SHA256SUMS`, it is skipped. If it is partial or stale, the downloader first lets `aria2c` try to resume/update the existing target. Only after a completed transfer still fails hash validation does it remove that single target file and retry once from zero.

## Scripts

### `backup-volume.sh`

Low-level volume export helper.

```sh
./scripts/docker/backup-volume.sh <volumeName> <fileNameWithoutExtension> <backupDir>
```

It exports one Docker/Podman volume into `<backupDir>/<fileNameWithoutExtension>.tar.gz`.

### `restore-volume.sh`

Low-level volume restore helper.

```sh
./scripts/docker/restore-volume.sh <volumeName> <fileNameWithoutExtension> <backupDir>
```

It restores one archive into one target volume. This is destructive for the target volume contents.

### `backup-sync.sh`

Low-level remote sync helper for one backup archive.

```sh
./scripts/docker/backup-sync.sh <remoteBackupURL> <volumeName> <fileNameWithoutExtension> <backupDir> [user] [password]
```

Use this directly when you need an emergency fallback for a single volume. It does not validate deployment-level policy such as `DLT`, `NETWORK`, service versions, or checksums; wrappers own that logic.

### `full-backup-sync.sh`

Full remote backup sync wrapper.

```sh
./scripts/docker/full-backup-sync.sh <remoteBackupURL> <projectNamePrefix> <backupDir> [user] [password]
```

It validates remote `READY` and `SHA256SUMS`, discovers project volumes, then delegates each archive download to `backup-sync.sh`.

### `full-backup.sh`

Full local backup wrapper.

```sh
./scripts/docker/full-backup.sh <projectNamePrefix> <backupDir>
```

It stops services for a clean backup, exports matching volumes, restores the local database password, then calls `create-backup-checksum.sh` to publish `READY` and `SHA256SUMS`.

### `full-restore.sh`

Full local restore wrapper.

```sh
./scripts/docker/full-restore.sh [projectNamePrefix] [backupDir]
```

It restores all matching project volumes from local backup files. This replaces deployment data.

### `create-backup-checksum.sh`

Canonical metadata and checksum generator.

```sh
./scripts/docker/create-backup-checksum.sh [backupDir]
```

It reads the local `.env`, writes `READY`, and creates a standard `SHA256SUMS` manifest for `READY` and all `.tar.gz` files in the backup directory.

### `db-sync-snapshot-sync.sh`

Downloads the configured cardano-db-sync bootstrap snapshot into `BACKUP_DIR` when snapshot restore variables are set.

### `compose.sh`

Small Docker Compose wrapper used by admin workflows.

### `list-volume-sizes.sh`

Reports Docker volume sizes to help estimate backup and restore storage requirements.

### `fix_db_pass.sh`

Utility for resetting the PostgreSQL password inside the running database service.

### `systemdAdd.sh`

Creates systemd integration for running the deployment on boot.
