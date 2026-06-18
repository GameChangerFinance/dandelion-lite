# Backup Sync Refactor Plan

Date: 2026-06-17

## Goal

Refactor the backup distribution workflow so local backup mirrors can self-heal safely, resume partial downloads, avoid duplicate disk use, and expose a reusable per-volume sync command without breaking existing human or script entrypoints.

The updated tactic is:

- wrapper-level sync orchestration must be governed by remote `READY` and hash files
- low-level download helpers must remain simple, direct, and emergency-fallback friendly
- wrappers must be the battle-tested daily path
- metadata must be easy to parse in shell and safe to validate before any download work starts
- keep code changes surgical and avoid modifying `full-backup.sh`, `full-restore.sh`, `restore-volume.sh`, `dandoman.sh`, and other working scripts unless a change is genuinely required

## Non-Negotiables

- Keep existing call signatures for current scripts.
- Preserve compatibility with humans and scripts that already call the helpers.
- Print usage and validation errors to `stderr` when required arguments are missing.
- Keep the implementation concise and maintainable.
- Do not create extra file copies when syncing backups.
- Prefer resuming and reusing partially downloaded data over restarting from zero.
- Do not weaken restore safety or integrity verification.
- Do not add extra dependencies or OS package installs if current tooling can solve the job.
- Keep standalone helpers as simple as possible and avoid wrapper-only assumptions leaking into them.
- Centralize local `READY` and checksum publication in `scripts/docker/create-backup-checksum.sh` so backup-set generation always goes through one canonical manifest path.
- Rename `scripts/docker/sha256sum-backups.sh` to `scripts/docker/create-backup-checksum.sh` and make that the canonical script for local `READY` and checksum generation.
- Update every script, doc, help text, and inline example across the repo that references `sha256sum-backups.sh` so they consistently reference `create-backup-checksum.sh`.

## Current Touch Points

- `scripts/docker/full-backup-sync.sh`
- `scripts/docker/backup-volume.sh`
- `scripts/docker/restore-volume.sh`
- `scripts/docker/create-backup-checksum.sh`
- `scripts/docker/full-backup.sh`
- `scripts/docker/full-restore.sh`
- `README.md`
- `AdminTool.md`
- `scripts/docker/README.md`
- `scripts/dandoman.sh`

## Target Design

### 1. Split responsibilities cleanly

- `backup-volume.sh` remains the low-level volume export helper.
- `restore-volume.sh` remains the low-level volume import helper.
- `backup-sync.sh` becomes the low-level per-volume remote sync helper.
- `full-backup-sync.sh` becomes a thin wrapper that discovers target volumes and delegates each file download to `backup-sync.sh`.
- `create-backup-checksum.sh` becomes the integrity manifest generator and verifier companion for backup directories.
- All existing doc and script references to the old checksum helper name must be updated in the same change so the repo stays consistent.

### 1a. Make the wrapper authoritative

- `full-backup-sync.sh` must inspect remote `READY` and hash files before syncing any payload.
- If remote `READY` is missing, the remote repository is invalid or not ready and the wrapper must fail fast.
- If remote `READY` exists but its `network` and `dlt` values do not match the local deployment environment, the wrapper must halt with an error.
- If remote `READY` matches `network` and `dlt` but `node` or `dbsync` versions differ from local values, the wrapper must warn loudly in uppercase and continue only if that is an intentional upgrade path.
- The low-level downloader must not own deployment policy; it only downloads one file cleanly when told to do so.

### 2. Make sync idempotent and self-healing

- If a local backup file is complete and matches remote content, keep it.
- If a local backup file is partial, resume it.
- If a local backup file differs from the remote source, first try to resume using aria2 control metadata, then replace it only if resume is impossible or the file still fails validation.
- If remote server headers are available, use them.
- If remote headers are missing or unreliable, fall back to content-based validation and resumable transfer heuristics.
- Never create temporary duplicate backup files alongside the target artifact.
- Never rely on rename-based fallback copies such as `.1`, `.2`, `.3`.
- Use the final backup filename as the only on-disk target for any in-progress download.
- On wrapper startup, remove any stale local `READY` and hash file before beginning a fresh remote sync pass.

### 3. Avoid duplicate files

- Configure `aria2c` so it does not create `.1`, `.2`, `.3` copies.
- Prefer in-place reuse of the target filename.
- Use resumable downloads directly into the destination path.
- If a file cannot be validated with confidence, do not add a second copy as a fallback.

### 4. Add a stable manifest layer

- Rename the metadata sidecar to `READY`.
- Publish a constant `READY` file alongside the backup files.
- Use it to record deployment metadata such as:
  - network tag
  - DLT tag
  - node version
  - dbsync version
  - source generation timestamp
  - optional source endpoint
- Make `READY` plain key-value text that is easy to parse with bash.
- Make `READY` plain key-value text-safe against human dummy whitespace errors.
- Make `READY` match the remote version verbatim after sync.
- Publish hashes in the standard uppercase `SHA256SUMS` file name.
- Use the standard GNU `sha256sum` untagged format so humans and scripts can verify and compare backup sets consistently.
- Do not embed deployment metadata in the checksum lines themselves.
- Keep metadata in the separate `READY` file, and include `READY` in the checksum manifest so it is integrity-protected.
- Have `scripts/docker/create-backup-checksum.sh` generate both `READY` and `SHA256SUMS` for local backup sets.
- Update every example command, script call site, and doc reference to the new script name so there is no mixed naming in the repo.

## Proposed File Behavior

### `scripts/docker/backup-sync.sh`

- Accept one volume name and one backup directory path, with the same style as `restore-volume.sh`.
- Derive the file name from the volume name when needed, or accept an explicit backup file stem if the existing calling pattern requires it.
- Download only the requested volume backup file.
- Prefer a single stable output path.
- Resume partial downloads.
- Validate the final file against available remote metadata or local hash manifests.
- Exit non-zero on validation failure.
- Use aria2 with the conservative no-duplicate settings: `--continue=true`, `--always-resume=false`, `--auto-file-renaming=false`, and any other flags needed to keep all writes on the final target path.
- Treat server headers as an optimization only, not as the source of truth.
- Treat the checksum manifest as the source of truth for deciding whether a local file is already valid.
- Stay as close as possible to a plain download primitive, so the script can also be used as an emergency fallback by humans or other scripts.
- If validation proves a file is stale or corrupt, prefer resuming against the existing target with aria2 resume metadata first, and only overwrite after the resume attempt has been exhausted or the file still fails verification.

### `scripts/docker/full-backup-sync.sh`

- Keep its current public call signature.
- Continue to discover compose volumes from the stack definition.
- Delegate the download of each volume file to `backup-sync.sh`.
- Keep orchestration logic thin and readable.
- Preserve current user-facing messaging style.
- Enforce remote `READY` and `SHA256SUMS` policy before syncing any payloads.
- Remove stale local `READY` and `SHA256SUMS` files before starting a fresh sync pass.
- After all downloads finish, fetch and publish the remote `READY` and `SHA256SUMS` files verbatim.

### `scripts/docker/create-backup-checksum.sh`

- Keep its current public call signature and design simplicity.
- Generate a normalized manifest for the backup directory using the standard `sha256sum` untagged output format.
- Generate the local `READY` file from `.env`/deployment values before writing hashes.
- Include the constant `READY` file in the manifest if present (do not exclude any present file).
- Avoid shell globs that accidentally include unrelated or transient files.
- Do not change the checksum line format to smuggle metadata into the digest file.
- Example line format:

  ```text
  <sha256-hex>  <filename>
  ```

## Metadata Strategy

The manifest layer should support only the essential fields, using the exact env-var style names from the repo examples:

- `DLT`
- `NETWORK`
- `CARDANO_NODE_VERSION`
- `CARDANO_DB_SYNC_VERSION`
- `UPDATED_AT`

Parsing rule:

- `READY` parsing must be position-agnostic.
- Any key order is valid as long as the required keys are present exactly once.
- The parser may ignore blank lines and comment lines, but it must not depend on a fixed line order.
- Validation must fail if a required key is missing or duplicated.

Preferred approach:

- publish `READY` as plain `key=value` lines
- publish one hash manifest for all backup artifacts in the directory using the standard `SHA256SUMS` file name
- make the hash file deterministic so it can be re-used by humans and automation
- keep metadata and checksums separate so `sha256sum -c` remains compatible
- make metadata keys stable and shell-friendly
- do not invent a new postgres version env var if the repository does not already define one in `.env.example*`
- if a postgres version needs to be published later, add it deliberately and map it to an existing repo source of truth instead of leaking unrelated service versions

Suggested `READY` keys:

- `DLT`
- `NETWORK`
- `CARDANO_NODE_VERSION`
- `CARDANO_DB_SYNC_VERSION`
- `UPDATED_AT`

## Implementation Order

1. Inspect and stabilize argument parsing and stderr usage in the target scripts.
2. Define the `READY` contract and the exact hash-file naming convention.
3. Introduce `backup-sync.sh` as a standalone per-volume downloader.
4. Refactor `full-backup-sync.sh` to gate on remote `READY` and hash files, then delegate to the new helper.
5. Rename `sha256sum-backups.sh` to `create-backup-checksum.sh`, then update it to emit normalized manifest data and generate the local `READY` file as the single source of truth for backup-set publication.
6. Update `full-backup.sh` and `full-restore.sh` only where they need to consume the new manifest conventions.
7. Update docs and operator help text.
8. Add regression tests and fixture coverage for:
   - missing arguments
   - resumed download behavior
   - exact filename reuse
   - remote READY gate failures
   - network/DLT mismatch failures
   - upgrade warnings for node/dbsync version drift
   - manifest generation
   - verification failure paths
   - interruption and resume behavior for partially downloaded files
   - overwrite behavior when a stale local file exists

## Verification Plan

- Run shell syntax checks on all touched scripts.
- Add focused tests for the downloader and manifest generator behavior.
- Validate that `full-backup-sync.sh` still works as the orchestration wrapper.
- Validate that the standalone `backup-sync.sh` works independently for one volume.
- Validate that backup verification fails loudly when hashes do not match.
- Validate that interrupted downloads resume into the same destination filename without creating `.1` copies.
- Validate that a file already matching the manifest is skipped rather than downloaded again.
- Validate that checksum verification uses the exact `sha256sum` line format and accepts the published `READY` sidecar separately.
- Validate that missing remote `READY` causes wrapper failure before any payload downloads.
- Validate that mismatched `network` or `dlt` causes wrapper failure.
- Validate that mismatched `node_version` or `dbsync_version` produces uppercase warnings and still requires explicit operator intent.
- Validate that `READY` and `SHA256SUMS` are re-fetched and published only after all payload files finish successfully.
- Run interruption-resume tests with a deliberately interrupted download and confirm the next run resumes instead of starting over.
- Run overwrite tests with a stale local file and confirm aria2 resume metadata is tried before the target file is replaced.
- Run the full sync workflow with locally installed `aria2c`; do not ship until that path has been exercised successfully.
- Validate that the renamed `create-backup-checksum.sh` entrypoint is still called by the full backup flow and produces the same `READY` plus `SHA256SUMS` artifacts.
- Validate that no repo docs, scripts, or examples still mention `sha256sum-backups.sh` after the rename.

## Risks To Watch

- Remote servers may not provide useful headers.
- Large files may require careful `aria2c` flags to avoid re-downloading.
- Hash verification must not create extra copies or write into the wrong directory.
- Existing scripts may depend on current stdout phrasing, so preserve human-readable output where practical.
- A wrapper that checks remote metadata too aggressively can block valid mirror refreshes if the metadata server is temporarily inconsistent.
- Uppercase warning output must remain readable and not become noise during normal upgrade workflows.
- Parsing `READY` must stay trivial for bash; avoid clever formats that require extra tools.

## Acceptance Criteria

- Existing entrypoints still work.
- A partially downloaded backup file resumes instead of restarting.
- A complete matching backup file is not downloaded again.
- A mismatched backup file is replaced or re-synced safely.
- No `.1`, `.2`, `.3` duplicate backup artifacts are created during sync.
- A stable `READY` artifact and normalized `SHA256SUMS` manifest are published alongside backups.
- The sync path is available both as a per-volume command and as a full-project wrapper.
- The wrapper refuses to sync from a remote that lacks `READY`.
- The wrapper refuses to sync when `network` or `dlt` diverges from local deployment values.
- The wrapper warns loudly on node/dbsync version drift but keeps the upgrade path explicit.
