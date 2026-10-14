# Volume Backup Operations

## Goal

Reduce deployment time and disk risk while keeping backup synchronization safe,
resumable, verifiable and usable by independent operators.

Cardano node and database volumes can be very large. Operators may not have room
for duplicate payload copies, and downloads can take hours, so interruption and
integrity handling are part of the public operational contract.

## Safety Contract

- Do not create duplicate backup artifacts such as `.1`, `.2` or `.3`.
- Do not create temporary staging copies for large backup payloads.
- Download into the final target filename and let `aria2c` resume it.
- If a completed download fails checksum verification, retry only that target file
  once after the wrapper removes it.
- Hashes are authoritative; HTTP headers are only an optimization.
- Gate remote synchronization on remote `READY`, `MD5SUMS` and `SHA256SUMS`.
- Use `MD5SUMS` only as a fast-change hint; final integrity is `SHA256SUMS`.
- Regenerate local checksums before reporting a successful sync.
- On final SHA256 failure, move `READY` to `old/READY` instead of deleting it.

`READY` is plain, position-independent `KEY=value` metadata and is copied
verbatim from a successful remote sync. It must contain:

```env
DLT=cardano
NETWORK=preprod
CARDANO_NODE_VERSION=11.0.1
CARDANO_DB_SYNC_VERSION=13.7.1.0
UPDATED_AT=2026-06-17T00:00:00Z
```

`DLT` and `NETWORK` mismatches are hard failures. Node and db-sync version
mismatches must show incoming and local values and require explicit operator
intent. Do not add unrelated service versions to `READY`.

`SHA256SUMS` uses the standard format:

```text
<sha256-hex>  <filename>
```

## Script Roles

| Script | Role |
| --- | --- |
| `scripts/docker/backup-volume.sh` | Low-level volume export helper |
| `scripts/docker/restore-volume.sh` | Low-level volume import helper |
| `scripts/docker/backup-sync.sh` | Low-level one-file remote download helper |
| `scripts/docker/full-backup-sync.sh` | Validates metadata, discovers volumes and delegates downloads |
| `scripts/docker/full-backup.sh` | Creates a local backup set |
| `scripts/docker/full-restore.sh` | Restores a local backup set |
| `scripts/docker/create-backup-checksum.sh` | Canonical local producer of `READY`, `MD5SUMS` and `SHA256SUMS` |

Do not reintroduce `sha256sum-backups.sh`.

## Verification

For backup synchronization, verify at least:

- missing remote `READY`;
- missing or invalid `SHA256SUMS`;
- DLT and network mismatch handling;
- version mismatch warnings and operator confirmation;
- already-valid local file skip behavior;
- stale file retry behavior;
- no duplicate download artifacts; and
- `sha256sum -c SHA256SUMS`.

Use disposable fixtures or Docker command shims for these tests. Do not touch
real Docker volumes without explicit operator approval.
