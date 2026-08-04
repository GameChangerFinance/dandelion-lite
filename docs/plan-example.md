# Backup Sync Master Plan

Date: 2026-06-18

## Goal

Refactor the backup distribution workflow so local backup mirrors can self-heal safely, resume partial downloads, avoid duplicate disk use, and expose a reusable per-volume sync command without breaking existing human or script entrypoints.

The implementation must also reduce operator wait time on huge backup sets by using `MD5SUMS` as a fast precheck while keeping `SHA256SUMS` as the final integrity authority.

The updated tactic is:

- wrapper-level sync orchestration must be governed by remote `READY`, `MD5SUMS`, and `SHA256SUMS`
- low-level download helpers must remain simple, direct, and emergency-fallback friendly
- wrappers must be the battle-tested daily path
- metadata must be easy to parse in shell and safe to validate before any payload download starts
- keep code changes surgical and avoid modifying `full-backup.sh`, `full-restore.sh`, `restore-volume.sh`, `dandoman.sh`, and other working scripts unless a change is genuinely required
- when final SHA verification fails, do not advertise the set as ready; move `READY` into `old/READY` instead of deleting it so operators can inspect the failed published metadata

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
- Preserve the current operator-friendly logging, emoji convention, and error wording style.

## Current Touch Points

- `scripts/docker/full-backup-sync.sh`
- `scripts/docker/backup-sync.sh`
- `scripts/docker/create-backup-checksum.sh`
- `scripts/docker/backup-volume.sh`
- `scripts/docker/restore-volume.sh`
- `scripts/docker/full-backup.sh`
- `scripts/docker/full-restore.sh`
- `README.md`
- `scripts/docker/README.md`
- local `AGENTS.md`

## Target Design

### 1. Split responsibilities cleanly

- `backup-volume.sh` remains the low-level volume export helper.
- `restore-volume.sh` remains the low-level volume import helper.
- `backup-sync.sh` stays the low-level per-volume remote sync helper.
- `full-backup-sync.sh` remains the wrapper that discovers target volumes and delegates each file download to `backup-sync.sh`.
- `create-backup-checksum.sh` becomes the canonical integrity manifest generator for backup directories.
- All existing doc and script references to the old checksum helper name must be updated in the same change so the repo stays consistent.

### 2. Make the wrapper authoritative

- `full-backup-sync.sh` must inspect remote `READY`, `MD5SUMS`, and `SHA256SUMS` before syncing any payload.
- If remote `READY` is missing, the remote repository is invalid or not ready and the wrapper must fail fast.
- If remote `READY` exists but its `NETWORK` and `DLT` values do not match the local deployment environment, the wrapper must halt with an error.
- If remote `READY` matches `NETWORK` and `DLT` but `CARDANO_NODE_VERSION` or `CARDANO_DB_SYNC_VERSION` differ from local values, the wrapper must warn loudly in uppercase and continue only if that is an intentional upgrade path.
- The low-level downloader must not own deployment policy; it only downloads one file cleanly when told to do so.

### 3. Make sync idempotent and self-healing

- If a local backup file is complete and matches remote content, keep it.
- If a local backup file is partial, resume it.
- If a local backup file differs from the remote source, first try to resume using aria2 control metadata, then replace it only if resume is impossible or the file still fails validation.
- If remote server headers are available, use them.
- If remote headers are missing or unreliable, fall back to content-based validation and resumable transfer heuristics.
- Never create temporary duplicate backup files alongside the target artifact.
- Never rely on rename-based fallback copies such as `.1`, `.2`, `.3`.
- Use the final backup filename as the only on-disk target for any in-progress download.
- On wrapper startup, remove any stale local `READY`, `MD5SUMS`, and `SHA256SUMS` before beginning a fresh remote sync pass.

### 4. Add a stable manifest layer

- Publish a constant `READY` file alongside the backup files.
- Use it to record deployment metadata such as:
  - `DLT`
  - `NETWORK`
  - `CARDANO_NODE_VERSION`
  - `CARDANO_DB_SYNC_VERSION`
  - `UPDATED_AT`
  - optional source endpoint or local-context fields when needed
- Make `READY` plain key-value text that is easy to parse with bash.
- Make `READY` position-agnostic and safe against human whitespace errors.
- Make `READY` match the remote version verbatim after sync, while allowing the wrapper to update only explicit local-context fields when required.
- Publish hashes in the standard uppercase `SHA256SUMS` file name.
- Publish a standard uppercase `MD5SUMS` file as a fast-change hint for reruns.
- Use the standard GNU `sha256sum` and `md5sum` untagged formats so humans and scripts can verify and compare backup sets consistently.
- Do not embed deployment metadata in the checksum lines themselves.
- Keep metadata in the separate `READY` file, and include `READY` in both checksum manifests so it is integrity-protected.
- Have `scripts/docker/create-backup-checksum.sh` generate `READY`, `MD5SUMS`, and `SHA256SUMS` for local backup sets.

## Proposed File Behavior

### `scripts/docker/backup-sync.sh`

- Keep the current public call signature stable.
- Stay as close as possible to a plain download primitive, so the script can also be used as an emergency fallback by humans or other scripts.
- Download only the requested volume backup file.
- Prefer a single stable output path.
- Resume partial downloads.
- Use aria2 with conservative no-duplicate settings so writes stay on the final target path.
- Do not make deployment-policy decisions here.
- Do not parse remote manifests here.
- Exit non-zero on transfer failure.

### `scripts/docker/full-backup-sync.sh`

- Keep its current public call signature.
- Continue to discover compose volumes from the stack definition.
- Delegate the download of each volume file to `backup-sync.sh`.
- Keep orchestration logic thin and readable.
- Preserve current user-facing messaging style.
- Enforce remote `READY`, `MD5SUMS`, and `SHA256SUMS` policy before syncing any payloads.
- Use remote `MD5SUMS` as the fast precheck to decide whether a local file likely needs a download.
- If a file already matches remote MD5, skip re-download.
- If a file does not match remote MD5, let `backup-sync.sh` try to resume/update the target first.
- After all downloads finish, run `create-backup-checksum.sh` locally to generate accurate local `READY`, `MD5SUMS`, and `SHA256SUMS`.
- Compare final local `SHA256SUMS` against the remote published `SHA256SUMS`.
- If the final SHA256 comparison fails, move `READY` to `old/READY` so the set is not advertised as ready yet, and exit non-zero.

### `scripts/docker/create-backup-checksum.sh`

- Keep its current public call signature and design simplicity.
- Generate normalized manifests for the backup directory using standard checksum output formats.
- Generate the local `READY` file from `.env`/deployment values before writing hashes.
- Include the constant `READY` file in the manifests if present.
- Avoid shell globs that accidentally include unrelated or transient files.
- Do not change checksum line formats to smuggle metadata into the digest files.
- Log file names and sizes in a human-friendly way.
- If the wrapper provides remote `READY` source values, preserve them and only update explicit local-context fields such as `UPDATED_AT`.

### `scripts/docker/full-backup.sh`

- Keep its current public call signature unless a change is genuinely required.
- Use `create-backup-checksum.sh` as the canonical local manifest generator.
- Do not introduce unrelated behavior changes.

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
- Blank lines and comment lines may be ignored.
- Validation must fail if a required key is missing or duplicated.

Preferred approach:

- publish `READY` as plain `key=value` lines
- publish one hash manifest for all backup artifacts in the directory using the standard `SHA256SUMS` file name
- publish `MD5SUMS` as a fast-change hint for sync reruns
- make the hash files deterministic so they can be re-used by humans and automation
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
2. Define the `READY` contract and the exact checksum file naming convention.
3. Keep `backup-sync.sh` as a standalone per-volume downloader with no policy logic.
4. Refactor `full-backup-sync.sh` to gate on remote `READY`, `MD5SUMS`, and `SHA256SUMS`, then delegate downloads to the low-level helper.
5. Ensure `create-backup-checksum.sh` emits `READY`, `MD5SUMS`, and `SHA256SUMS` canonically for local backup sets.
6. Update `full-backup.sh` and `full-restore.sh` only where they need to consume the new manifest conventions.
7. Update docs and operator help text, including `README.md`, `scripts/docker/README.md`, and local `AGENTS.md`.
8. Add regression tests and fixture coverage for:
   - missing arguments
   - resumed download behavior
   - exact filename reuse
   - remote READY gate failures
   - MD5 fast-check skip behavior
   - network/DLT mismatch failures
   - upgrade warnings for node/dbsync version drift
   - manifest generation
   - verification failure paths
   - interruption and resume behavior for partially downloaded files
   - overwrite behavior when a stale local file exists
   - moving `READY` into `old/READY` on final SHA failure

## Verification Plan

- Run shell syntax checks on all touched scripts.
- Add focused tests for the downloader and manifest generator behavior.
- Validate that `full-backup-sync.sh` still works as the orchestration wrapper.
- Validate that the standalone `backup-sync.sh` works independently for one volume.
- Validate that backup verification fails loudly when hashes do not match.
- Validate that interrupted downloads resume into the same destination filename without creating `.1` copies.
- Validate that a file already matching `MD5SUMS` is skipped rather than downloaded again.
- Validate that checksum verification uses the exact `sha256sum` line format and accepts the published `READY` sidecar separately.
- Validate that missing remote `READY` causes wrapper failure before any payload downloads.
- Validate that missing remote `MD5SUMS` or `SHA256SUMS` causes wrapper failure before any payload downloads.
- Validate that mismatched `NETWORK` or `DLT` causes wrapper failure.
- Validate that mismatched `CARDANO_NODE_VERSION` or `CARDANO_DB_SYNC_VERSION` produces uppercase warnings and still requires explicit operator intent.
- Validate that `READY`, `MD5SUMS`, and `SHA256SUMS` are re-fetched and published only after all payload files finish successfully.
- Run interruption-resume tests with a deliberately interrupted download and confirm the next run resumes instead of starting over.
- Run overwrite tests with a stale local file and confirm aria2 resume metadata is tried before the target file is replaced.
- Run the full sync workflow with locally installed `aria2c`; do not ship until that path has been exercised successfully.
- Validate that the renamed `create-backup-checksum.sh` entrypoint is still called by the full backup flow and produces the same `READY`, `MD5SUMS`, and `SHA256SUMS` artifacts.
- Validate that no repo docs, scripts, or examples still mention `sha256sum-backups.sh` after the rename.
- Validate that a final SHA mismatch moves `READY` into `old/READY` and leaves the rest of the files intact for inspection.
- Validate the wrapper and low-level helper with a wrong or failing URL to ensure no local files are harmed by broken remote endpoints.

## Risks To Watch

- Remote servers may not provide useful headers.
- Large files may require careful `aria2c` flags to avoid re-downloading.
- Hash verification must not create extra copies or write into the wrong directory.
- Existing scripts may depend on current stdout phrasing, so preserve human-readable output where practical.
- A wrapper that checks remote metadata too aggressively can block valid mirror refreshes if the metadata server is temporarily inconsistent.
- Uppercase warning output must remain readable and not become noise during normal upgrade workflows.
- Parsing `READY` must stay trivial for bash; avoid clever formats that require extra tools.
- Preserving `READY` in `old/READY` on failure must not accidentally advertise a broken set as usable.

## Acceptance Criteria

- Existing entrypoints still work.
- A partially downloaded backup file resumes instead of restarting.
- A complete matching backup file is not downloaded again.
- A mismatched backup file is replaced or re-synced safely.
- No `.1`, `.2`, `.3` duplicate backup artifacts are created during sync.
- A stable `READY` artifact plus normalized `MD5SUMS` and `SHA256SUMS` manifests are published alongside backups.
- The sync path is available both as a per-volume command and as a full-project wrapper.
- The wrapper refuses to sync from a remote that lacks `READY`.
- The wrapper refuses to sync when `NETWORK` or `DLT` diverges from local deployment values.
- The wrapper warns loudly on node/dbsync version drift but keeps the upgrade path explicit.
- The wrapper uses `MD5SUMS` to avoid unnecessary re-downloads.
- The wrapper still validates final integrity with `SHA256SUMS`.
- A final SHA failure moves `READY` into `old/READY` instead of deleting it.
- The docs and AGENTS files explain the fast-check flow and the operator expectations clearly.
