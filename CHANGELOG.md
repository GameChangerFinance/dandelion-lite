# Changelog

Notable operator-facing changes to Dandelion Lite will be recorded here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and a project-level `MAJOR.MINOR.PATCH` release scheme.

## [Unreleased]

### Changed

- Added a visitor-count badge to the README.

### Fixed

- `scripts/docker/restore-volume.sh` now exits before emptying the volume when the
  backup archive is missing or unreadable. Previously a wrong file name, or a volume
  without a matching archive during `full-restore.sh`, left the volume empty.
- `scripts/docker/backup-volume.sh` now runs its export container with `docker` instead
  of `podman`, like the image pull just before it and `restore-volume.sh`. Full backups
  failed on hosts installed with `dandoman.sh --docker-install` (no `podman` binary);
  Podman hosts are unchanged, as the Podman install provides `docker` via `podman-docker`.
- `dandoman.sh` *Config → Edit Entry* and *Remove Entry* now change `.env` on Linux.
  They used the BSD-only `sed -i ''`, which GNU sed rejects: sed printed an error and `.env` was not
  changed on Ubuntu.
- `dandoman.sh` asks for the network on the very first run again (#8). The question used
  `gum` before the dependencies (including `gum`) were installed, so no `.env` was created
  and the first session ran with empty variables. Dependencies are now installed first,
  and the new `.env` is loaded for the current session.

## [1.0.0] - 2026-10-14

### Added
- Native HAProxy ACME certificate issuance and renewal through the MyAddr DNS-01
  provider.
- Explicit TLS configuration through `TLS_ENABLED` and `ACME_ENABLED`.
- Dandoman SSL actions for self-signed certificate application, automatic
  renewal, and safe SSL status inspection.
- HAProxy Data Plane API configuration and a repository-built HAProxy 3.4.4
  ingress image with s6 supervision.
- Centralized SSL, backup, documentation, governance, contribution, security,
  and release-maintenance guidance.
- Isolated SSL regression checks covering provider behavior, certificate
  persistence, Compose modes, Docker, Podman, and local ACME issuance.

### Changed
- HAProxy now owns certificate issuance, renewal, activation, and persistence;
  successful automatic renewals are applied without restarting HAProxy.
- Self-signed certificates are written directly to
  `secrets/ssl/server.pem` and applied by restarting HAProxy, without candidate
  files or certificate rotation backups.
- Manual certificates use a combined private-key/full-chain PEM at
  `secrets/ssl/server.pem`.
- HAProxy startup tolerates unavailable backend DNS and uses hardened TLS,
  privilege, socket, and private-state handling.
- MyAddr dynamic DNS updates no longer submit static ACME challenges while
  native ACME is enabled.
- Dandoman state-changing SSL actions now provide cancellation prompts,
  expected outcomes, summaries, and safe operator-facing status output.
- Root and directory documentation now point to canonical guides, and the
  hardware/storage report reflects current production measurements.

### Fixed
- Self-signed key generation now reports OpenSSL failures correctly and cleans
  up temporary private material.
- MyAddr ACME responses, challenge validation, credential handling, and request
  timeouts are validated without exposing secrets.
- Certificate and ACME account files are protected with owner-only permissions,
  including after native HAProxy writes them.
- Dandoman CLI failures now propagate correctly instead of being hidden by the
  interactive wrapper.

### Removed
- Certbot, its cron renewal job, authentication/application hooks, email and
  propagation settings, package dependency, and Let’s Encrypt state mount.
- The `configs/ssl/server.pem` candidate workflow and
  `scripts/ssl/rotate-ssl-and-restart-haproxy.sh`.
- SSL certificate rotation backups such as `server.pem.old.N`.
- The `--ssl-certbot-renew` and `--ssl-rotate` dandoman commands.
- Dandoman’s automatic writes to user shell startup files.

### Breaking changes and migration
- Replace `CERTBOT_ENABLED` with `ACME_ENABLED` and set `TLS_ENABLED=true`
  when HTTPS is required.
- Replace `--ssl-certbot-renew` with `--ssl-renew`.
- Remove use of `configs/ssl/server.pem`, `secrets/letsencrypt/`, and the old
  rotation command.
- Rebuild and recreate HAProxy and cron after upgrading so the new image,
  mounts, environment variables, and runtime configuration are applied:

  ```sh
  docker compose build haproxy cron
  docker compose up -d --no-deps --force-recreate haproxy cron
  ./scripts/dandoman.sh --ssl-status
  ```

- Existing Certbot state is not imported into native HAProxy ACME. Operators
  should privately preserve any needed certificate material before migration.

[Unreleased]: https://github.com/GameChangerFinance/dandelion-lite/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/GameChangerFinance/dandelion-lite/releases/tag/v1.0.0
