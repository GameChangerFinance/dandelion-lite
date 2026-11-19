# Changelog

Notable operator-facing changes to Dandelion Lite will be recorded here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and a project-level `MAJOR.MINOR.PATCH` release scheme.

## [Unreleased]

## [1.1.0] - 2026-11-19

### Added

- Optional `admin` Compose profile with pgAdmin 9.19, preserving automatic UI
  access and PostgreSQL login. See [development guidance](docs/development.md)
  for host ports, SSH access and stopping tools independently of the main stack.

### Changed

- Update NGINX to 1.30.7-alpine, HAProxy to s6-3.4.8 and the PostgreSQL base
  to 18.7-bookworm, without a PostgreSQL major-version migration. HAProxy's
  upstream image now uses gopherd supervision; startup and Data Plane API reload
  commands are adapted accordingly.
- To apply the NGINX, HAProxy and PostgreSQL image updates locally, set `NGINX_VERSION=1.30.7` in your existing `.env`, then run `docker compose build --pull --no-cache SERVICE` followed by `docker compose up -d --no-deps --force-recreate SERVICE` for each service (`nginx`, `haproxy`, `postgress`) separately, allowing for a brief service interruption while preserving existing data volumes.
- Rebuild pgAdmin with `docker compose --profile admin build --pull --no-cache pgadmin`,
  then apply it with `docker compose --profile admin up -d --no-deps --force-recreate pgadmin`
  while PostgreSQL is healthy. Existing pgAdmin settings are retained. The tool
  is optional and now bound to localhost; use `docker compose port pgadmin 80`
  to find its address, or an SSH tunnel for remote access. Stop only the tool
  with `docker compose stop pgadmin`.
- Generate pgAdmin connection files at startup from a runtime secret instead of
  embedding database credentials in the image. Owner-only permissions allow
  pgAdmin's non-root runtime user to read the passfile without a password prompt.
- Document shared systemd, menu and Compose deployment controls, and clarify that
  installing autostart enables the service without starting it (#12, including #11).
- Added a visitor-count badge to the README.
- README base system install now lists `git` as a prerequisite (#5).
- Document ngrok installation and account setup through the official guide, and
  clarify temporary, interactive usage for development and testing (#9).

### Fixed

- Quote GraphQL CORS and PostgREST aggregate flags in Compose environment values
  so providers receive strings instead of rejecting YAML booleans.
- Accept both zone-relative and fully qualified DNS challenge names from Data
  Plane API in the MyAddr callback, restoring DNS-01 issuance and renewal with
  the updated HAProxy image.
- Strengthen ACME regression checks to require replacement of an expired
  certificate with a valid one and avoid false failures when reading long logs.
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

### Security

- Remove the outdated `dbless-cardano-token-registry` source, cron job, configuration
  and endpoint references so it cannot be re-enabled from this distribution.
- Restrict root build contexts to the required Dockerfiles and HAProxy entrypoint,
  excluding local credentials, data and other workspace files from those contexts.
- Prevent the known NGINX entry points of [nginx2root](https://xint.io/blog/nginx2root-remote-code-execution)
  by updating NGINX to 1.30.7-alpine. The five NGINX CVEs in that attack chain are
  fixed in this version according to the [official advisories](https://nginx.org/en/security_advisories.html):

  | CVE | Upstream finding |
  | --- | --- |
  | CVE-2026-123007 | Memory corruption in HTTP/2 flow control |
  | CVE-2026-123633 | Use-after-free in HTTP/2 |
  | CVE-2026-121810 | Use-after-free in HTTP/3 |
  | CVE-2026-123634 | Use-after-free in resolver response processing |
  | CVE-2026-113425 | Use-after-free in the mail proxy module |

  Existing deployments must rebuild and recreate NGINX to receive these fixes.
  Host kernel/SCTP and firewall recommendations are in [SECURITY.md](SECURITY.md);
  container updates do not patch the host kernel or configure its firewall.
- Pin pgAdmin to 9.19, which includes fixes for these 15 CVEs in the
  [official release notes](https://www.pgadmin.org/docs/pgadmin4/9.19/release_notes_9_19.html):
  CVE-2026-116238, CVE-2026-116239, CVE-2026-116240, CVE-2026-116241,
  CVE-2026-116242, CVE-2026-116243, CVE-2026-116244, CVE-2026-116245,
  CVE-2026-116246, CVE-2026-116247, CVE-2026-116248, CVE-2026-116249,
  CVE-2026-116250, CVE-2026-116251 and CVE-2026-116252. Several concern optional
  server-mode features; the standard desktop-mode automatic login is retained.
  These are the targeted upstream security fixes, not an exhaustive list of all
  CVEs fixed by the image updates or a claim that every image is vulnerability-free.

### Upgrade and compatibility

- No intentional changes to public API routes or response formats in the standard
  stack. PostgreSQL stays on major version 18; existing PostgreSQL data volumes
  require no major-version migration. Retain named volumes when recreating services.
- Back up configuration and data before upgrading. Rebuild and recreate the updated
  services individually using the commands above; allow for brief interruptions.
  Restart cron with `docker compose restart cron` to reload its job list.
- pgAdmin requires explicit activation through the `admin` profile. Its port is
  localhost-only; remote operators should use an SSH tunnel. Migration of settings
  from older pgAdmin volumes has not been validated.
- Custom deployments that manually enabled `dbless-cardano-token-registry` must
  replace that service before upgrading. The standard Compose stack did not enable it.
- Keep the previous source revision, image IDs and configuration for rollback.
  Restore them together; do not delete data volumes. If an application changes
  persisted settings, use its pre-upgrade backup rather than assuming a downgrade
  can read the newer state.

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

[Unreleased]: https://github.com/GameChangerFinance/dandelion-lite/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/GameChangerFinance/dandelion-lite/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/GameChangerFinance/dandelion-lite/releases/tag/v1.0.0
