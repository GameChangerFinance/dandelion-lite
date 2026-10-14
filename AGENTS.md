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
- Every `dandoman.sh` action that changes deployment state, especially critical
  actions, must state what it will do and give the operator a clear chance to
  cancel before it starts. On completion, show a brief outcome summary and any
  useful next step.

Emoji convention for shell script messages:

- `❌` errors
- `⚠️` warnings or risky prompts
- `ℹ️` info/status
- `✅` final success/completion

Use `✅` sparingly. Prefer one final success status per script or operation instead of marking every intermediate step successful.

Keep semantic emojis minimal and consistent: use `❌` for errors, `⚠️` for risks
or cancellation points, `ℹ️` for status, and one `✅` for completed work.

## Wrapper vs Low-Level Helpers

Goal: make daily workflows safe while preserving emergency fallback tools.

Keep a strict boundary:

- wrappers own policy, orchestration, validation, parsing, and multi-step decisions
- low-level scripts do one direct task with minimal assumptions
- low-level scripts should be usable manually during emergencies
- wrapper logic must not leak complex deployment policy into low-level helpers
- Keep `dandoman.sh` a thin wrapper around focused helper scripts. When a menu or
  CLI action needs more than roughly ten lines and has a coherent standalone
  purpose, move that behavior into `scripts/` and let dandoman handle prompts,
  summaries and delegation.

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
- Keep full operator contracts in focused `docs/` files. Root and directory
  READMEs should be short pointers, and AGENTS.md should retain only maintainer
  coding and architectural rules.
- `docs/ssl.md` is authoritative for TLS behavior and operations;
  `docs/backups.md` is authoritative for backup operations. Do not duplicate or
  fork those contracts in READMEs, scripts or AGENTS.md.

## Backup Implementation

`docs/backups.md` owns the backup protocol, public script roles and operator
workflow. Preserve those contracts when changing backup code; keep wrappers as
policy/orchestration layers and low-level helpers narrow and directly usable.

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

For backup sync changes, run the scenario coverage defined in `docs/backups.md`
using disposable fixtures; never test against real Docker volumes.

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
