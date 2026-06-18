# AGENTS.md

Repository guidance for Codex, code assistants, and automation agents working on Dandelion Lite.

## Main Goal

Help Dandelion Lite become a reliable, self-hostable Cardano infrastructure distribution that lets many independent Dandelion Node Operators deploy compatible node and API services.

The project goal is not only easier deployment. The larger goal is decentralizing the backend service layer used by Cardano wallets, dApps, education platforms, explorers, analytics services, and community infrastructure.

Read and preserve the project concept in:

```text
docs/concept.md
```

That file is the reference for why Dandelion Lite exists: avoid centralized backend dependence, support universal Cardano APIs, enable DNO participation, publish machine-readable manifests, and support client-side discovery/load balancing.

## Goal Discipline

Before and after each update, feature, or fix, make the goal explicit.

For every non-trivial task:

- ask or infer the immediate goal
- state the maintainer outcome being protected
- identify any nested feature goal affected by the change
- after finishing, ask what goal should be pursued next when there are natural follow-ups

Do not treat scripts, docs, packaging, or API changes as isolated edits. Connect them back to operator experience, decentralization, deployability, and production reliability.

## Contribution Rules

Goal: keep the project production-safe while improving operator experience.

- Inspect current files before editing.
- Keep changes surgical and current-code-aware.
- Do not rewrite working scripts just to make them stylistically nicer.
- Do not tamper with already-working path semantics unless the user explicitly requests a path behavior change.
- Preserve public script call signatures unless the user explicitly approves a breaking change.
- Treat helper scripts as production entrypoints used by both humans and automation.
- Avoid new external dependencies and OS package installs unless the existing toolchain cannot solve the task.
- Prefer tools already used by this repo.
- Keep code simple enough for operators to debug during an incident.
- Add comments only when they explain non-obvious safety, compatibility, or protocol behavior.
- Keep user-facing messages concrete and actionable.
- Preserve existing wording style, usage hints, and operational tips unless asked to change them.
- Run focused tests after every script behavior change.
- Never claim tests passed unless they were actually run.

## Script Design

Goal: keep scripts human-friendly and automation-safe.

Dandelion Lite scripts are used by operators directly and by wrapper scripts such as `scripts/dandoman.sh`. They must remain suitable for both.

Rules:

- Required argument errors must print usage/help text.
- Human logs should be readable and explicit.
- Machine-relevant behavior must be deterministic.
- Missing required arguments and validation failures should exit non-zero.
- Prefer stdout for normal progress and stderr for validation or failure messages.
- Do not hide destructive actions.
- Do not silently change files, volumes, or deployment state without clear logs.
- Keep backup and restore operations especially conservative.

Emoji convention for shell script messages:

- `❌` errors
- `⚠️` warnings or risky prompts
- `ℹ️` info/status
- `✅` final success/completion

Use `✅` sparingly. Prefer one final success status per script or operation instead of marking every intermediate step successful.

## Wrapper vs Low-Level Helpers

Goal: make daily workflows safe while preserving emergency fallback tools.

Keep a strict boundary:

- wrappers own policy, orchestration, validation, parsing, and multi-step decisions
- low-level scripts do one direct task with minimal assumptions
- low-level scripts should be usable manually during emergencies
- wrapper logic must not leak complex deployment policy into low-level helpers

Examples:

- `full-backup-sync.sh` may validate remote metadata, compare versions, decide whether to skip or retry files, and delegate downloads.
- `backup-sync.sh` should only download one requested backup archive cleanly.
- `create-backup-checksum.sh` is the canonical local producer of `READY`, `MD5SUMS`, and `SHA256SUMS`.
- `backup-volume.sh` and `restore-volume.sh` should stay narrow volume export/import primitives.

## Documentation

Goal: make the repo operable by more independent node operators.

Documentation is part of production reliability. Update docs when behavior changes.

Rules:

- Keep root `README.md` concise and operator-oriented.
- Add a `README.md` to relevant directories that contain important operational scripts, configs, or workflows.
- Directory READMEs should follow the style of `configs/README.md`: clear title, purpose, important files, operational behavior, examples, and warnings.
- Keep script usage examples synchronized with actual call signatures.
- Avoid stale names after renames.
- Keep docs explicit about destructive behavior, backup/restore risk, and required operator intent.

## Volume Backup System

Goal: reduce deployment time and disk risk while keeping backup sync safe, resumable, verifiable, and usable by many operators.

Context:

- Cardano node and database volumes can be very large.
- Operators may not have enough disk for duplicate temporary files.
- Downloads can take hours and failures must resume where possible.
- Backup scripts affect production deploys and must be treated as high risk.

Design rules:

- Do not create duplicate backup artifacts such as `.1`, `.2`, `.3`.
- Do not use temporary staging copies for large backup payloads.
- Use the final target filename for in-progress downloads.
- Let `aria2c` resume before replacing a local file.
- If a completed transfer still fails checksum verification, wrappers may remove only that single target file and retry once.
- Hashes are the source of truth; HTTP headers are only an optimization.
- Remote backup sync must be gated by remote `READY`, `MD5SUMS`, and `SHA256SUMS`.
- `MD5SUMS` may be used as a fast-change hint to avoid expensive SHA256 hashing before downloads.
- `SHA256SUMS` remains the final integrity authority and must be regenerated locally after sync before reporting success.
- If final SHA256 verification fails, move `READY` to `old/READY` instead of deleting it, so the set is clearly marked not-ready.
- Missing remote `READY` means the remote backup repository is not ready or invalid.
- `DLT` and `NETWORK` mismatches are hard failures.
- `CARDANO_NODE_VERSION` and `CARDANO_DB_SYNC_VERSION` mismatches must warn with incoming and local values and require explicit operator intent.
- `READY` must be plain `KEY=value` metadata, position-agnostic, easy to parse in Bash, and copied verbatim from the remote after a successful full sync.
- `SHA256SUMS` must use the standard `sha256sum` format:

```text
<sha256-hex>  <filename>
```

Required `READY` keys:

```env
DLT=cardano
NETWORK=preprod
CARDANO_NODE_VERSION=11.0.1
CARDANO_DB_SYNC_VERSION=13.7.1.0
UPDATED_AT=2026-06-17T00:00:00Z
```

Do not publish unrelated service versions in `READY`. Avoid exposing versions such as nginx, Blockfrost, Unimatrix, or other unrelated services unless a future task explicitly defines a need and risk model.

## Backup Script Roles

Goal: keep each backup script understandable and replaceable during incidents.

- `backup-volume.sh`: low-level volume export helper.
- `restore-volume.sh`: low-level volume import helper.
- `backup-sync.sh`: low-level one-file remote download helper.
- `full-backup-sync.sh`: wrapper that validates remote backup metadata, discovers expected volumes, and delegates payload downloads.
- `full-backup.sh`: wrapper for creating a local backup set.
- `full-restore.sh`: wrapper for restoring local backup sets.
- `create-backup-checksum.sh`: canonical generator for local `READY`, `MD5SUMS`, and `SHA256SUMS`.

Do not reintroduce `sha256sum-backups.sh`. The canonical checksum script is:

```text
scripts/docker/create-backup-checksum.sh
```

## Testing Expectations

Goal: ship changes that do not break production operators.

For shell script changes:

- run `bash -n` on touched scripts
- test missing required argument paths
- test success paths with small local fixtures when possible
- for downloader changes, test real `aria2c` behavior when available
- verify no duplicate download files are created
- verify checksum success and failure paths
- avoid touching real Docker volumes unless the user explicitly approves it
- use fake or isolated Docker command shims/functions only when needed to avoid mutating local deployment state

For backup sync changes, verify at least:

- missing remote `READY`
- missing or invalid `SHA256SUMS`
- `DLT` mismatch
- `NETWORK` mismatch
- node/db-sync version mismatch warning
- already-valid local file skip
- stale local file retry behavior
- no `.1`, `.2`, `.3` duplicate files
- `sha256sum -c SHA256SUMS`

## Dependency Policy

Goal: keep deployment easy on ordinary operator machines.

- Do not add package installs casually.
- Prefer tools already installed by `scripts/dandoman.sh` or already used in the repo.
- If a new dependency is unavoidable, document why existing tools are insufficient.
- Prefer standard shell tools over language runtimes for small operational scripts.
- Do not add parsing formats that require new tools when plain Bash-friendly formats work.

Known accepted tools already used in this repo include Docker/Podman, Docker Compose, `aria2c`, `sha256sum`, `awk`, `sed`, `realpath`, `mktemp`, `find`, `sort`, `curl`, `jq`, and `psql`, depending on script area.

## Operator Experience

Goal: make more deployments possible by reducing operator uncertainty.

Good operator UX means:

- clear step logging
- concrete error messages with expected argument shape
- warnings for destructive or risky operations
- incoming vs local values in mismatch errors
- recovery hints where useful
- no silent fallbacks that hide data integrity problems
- no surprising disk amplification
- no unexpected call signature changes
- do not leak maintainer absolute filesystem paths, user `.env` files, backup directories, private keys, or other sensitive traces in logs, docs, screenshots, or prompt text

When changing scripts, review the exact output operators will see during a real deployment.

## Production Compatibility

Goal: avoid breaking existing deployments and automation.

Treat these as public interfaces:

- script filenames
- positional argument order
- environment variable names
- backup file names
- metadata file names
- checksum format
- Docker volume naming conventions
- public docs examples

Renames require repo-wide consistency updates. When a rename is intentional, remove stale references and decide explicitly whether a compatibility wrapper is allowed. Do not keep compatibility wrappers if the task explicitly asks for a strict rename.

## Cardano Service Layer

Goal: preserve broad compatibility for reusable Cardano backend APIs.

Dandelion Lite exists to deploy universal backend systems that many projects can share. Avoid changes that make the stack narrowly useful for one app unless the user explicitly asks for a scoped customization.

Preserve:

- Cardano node and Ogmios integration
- cardano-db-sync-backed services
- Koios-style APIs
- Blockfrost-compatible APIs
- Cardano GraphQL MKII
- Submit API
- token registry services
- manifests and node metadata

When changing service config, consider client compatibility and the Dandelion Network discovery model described in `docs/concept.md`.
