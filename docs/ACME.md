# Native ACME With MyAddr

## Goal

Dandelion Lite's automatic SSL path is intentionally small: HAProxy owns ACME
issuance, renewal, live activation and persistence for the MyAddr domain used by
the deployment. Cron keeps only the dynamic IP update job. It does not receive
certificate storage, HAProxy control sockets, Docker/Podman control or host-side
renewal authority.

This keeps operator-selected ingress ports, avoids host cron, avoids port 80/443
requirements, and keeps plaintext plus manual/self-signed TLS available when
automation is disabled.

## Current Behavior

Automatic mode is selected by all of these conditions:

- `TLS_ENABLED=true`.
- `ACME_ENABLED=true`.
- `MYADDR_DOMAIN` contains the MyAddr registration label.
- `MYADDR_TOKEN` contains the matching MyAddr token.

When those are true, HAProxy's native ACME support and its official Data Plane
API companion request, renew, apply and persist the certificate for:

```text
${MYADDR_DOMAIN}.myaddr.io
```

The certificate is written directly to `secrets/ssl/server.pem`, mounted inside
ingress at `/var/lib/haproxy/ssl/server.pem`. The persistent ACME account key is
`secrets/ssl/myaddr.account.key`.

Fresh automatic storage can issue without a pre-existing PEM. Existing long-lived
self-signed certificates and domain changes require one manual renewal request
after migration because HAProxy's native scheduler is certificate-lifetime based,
not a migration detector:

```sh
./scripts/dandoman.sh --ssl-renew
```

After that, routine renewal is automatic. Do not schedule `--ssl-renew`; repeated
manual requests can waste CA rate limits.

HAProxy does not use a fixed Dandelion cron schedule for ACME. Each certificate
has a native ACME task whose next run is based on the certificate expiration
date. Operators should inspect the exact next renewal with:

```sh
docker compose exec -T haproxy /scripts/ssl/haproxy-acme.sh status
```

The `scheduled date (UTC)` and `scheduled in` columns are the source of truth.
For ordinary Let's Encrypt 90-day certificates this is expected to be near the
end of the lifetime, but the repo intentionally does not encode a renewal day
threshold.

If `TLS_ENABLED=true` and automatic mode is disabled, HAProxy uses manual TLS and
expects `secrets/ssl/server.pem` to already exist. If `ACME_ENABLED=true` but
MyAddr credentials are incomplete, startup fails with an operator-facing error.
Plaintext is selected with `TLS_ENABLED` empty or false.

## MyAddr Exec Glue

The adapter is `scripts/ssl/myaddr-acme.sh`. It is called by the official HAProxy
Data Plane API ACME exec provider, not by cron.

The companion provides callback variables such as `ACTION`, `ZONE`, `REC_NAME`,
`REC_TYPE` and `REC_DATA`. The adapter accepts only the expected DNS-01 TXT
challenge for the configured MyAddr registration:

```text
_acme-challenge.${MYADDR_DOMAIN}.myaddr.io
```

For `set` and `append`, it posts encoded form fields to MyAddr over HTTPS:

- `key`: from `MYADDR_TOKEN`, passed through stdin to keep it out of process
  arguments.
- `acme_challenge`: from the ACME TXT value.

Success requires HTTP 200 and response body `OK`. Requests are bounded, TLS
verification remains enabled, provider response bodies are not printed, and
unsupported actions fail nonzero.

For `delete`, the adapter returns success without calling MyAddr. MyAddr expires
temporary TXT challenge records automatically; its HTTP DELETE path removes IP
records, so using it as ACME cleanup would be dangerous for the dynamic DNS
feature.

The separate MyAddr cron updater still updates the public IP. In automatic mode
it suppresses legacy static TXT challenge updates so it cannot overwrite the
native ACME challenge.

## Network Model

DNS-01 does not require any inbound challenge port. Operators keep their existing
`HAPROXY_PORT`; no extra public port, port 80, or port 443 is required for ACME.

Ingress needs outbound HTTPS to MyAddr and the ACME CA, plus working DNS
resolution and authoritative DNS propagation visibility for the companion's
checks. Issuance can work behind CGNAT. Public API reachability is separate:
clients still need a route to the chosen ingress port through the operator's
network setup.

HTTP-01 was rejected for this project because it requires port 80 and would
force a public-port policy that Dandelion operators explicitly cannot share.

## Security Boundary

Only ingress mounts `secrets/ssl/` and holds the local management sockets. Cron
and application guests do not get those sockets, the active PEM directory or
container-engine authority.

Data Plane API is configured for local Unix-socket use, with no published TCP
management API and no usable login. HAProxy workers drop privileges; the master
and companion remain root inside the ingress container because they must read and
replace private certificate files. This limits cross-service blast radius, but it
is not a defense against an attacker who already controls ingress container root.

Keep `secrets/ssl/` mode `0700`. The pinned official persistence library writes
combined PEM files as `0644`, overriding umask. The owner-only parent directory
is therefore the primary enforced access boundary. The ingress entrypoint sets
and verifies `0700` on that exact mounted directory, refuses symlinked
certificate or account-key paths, and tightens `server.pem` plus
`myaddr.account.key` to `0600` when they exist. A small in-container guard keeps
those exact files protected after native ACME writes or replaces them. It does
not recursively chmod, chown or delete operator files.

Exported copies of private PEM material must be protected separately with
`0600`.

## Why Certbot Was Removed

The previous Certbot flow was a bad fit for this deployment because it mixed
issuance, activation and service control across the wrong boundaries:

- Cron generated certificate candidates but HAProxy served
  `secrets/ssl/server.pem`, so successful issuance did not automatically update
  live ingress.
- Cron lacked safe access to HAProxy control or the active certificate mount.
  Granting Docker/Podman or HAProxy control to that guest would enlarge the
  compromise boundary.
- The active certificate was mounted as a single read-only file. Replacing a
  pathname elsewhere does not necessarily update the inode HAProxy has mounted.
- The TLS bind was independent from the old Certbot enablement flag, so disabling
  Certbot did not mean plaintext and fresh TLS still needed an active PEM.
- The DNS hook used a fixed sleep and did not rely on the ACME solver's native
  propagation checks.
- The DDNS job could submit stale static challenge data while Certbot was trying
  to solve DNS-01.
- Certbot state lived under a separate `secrets/letsencrypt/` lifecycle that
  native HAProxy cannot use directly.
- The old cron invocation used Certbot-specific behavior and flags that changed
  across Certbot versions, including a removed manual-public-IP logging flag.
- Documentation and helper commands implied restart or manual rotation could
  finish the lifecycle, but environment and mount changes need container
  recreation, and candidate rotation was never unattended renewal.

The old design was therefore not only broken in practice; repairing it cleanly
would have required more glue, more privilege sharing and more operational
states. Native HAProxy ACME collapses the lifecycle into the ingress boundary:
the process that terminates TLS also owns issuance, renewal, activation and
persistence.

Old Certbot account files may remain in `secrets/letsencrypt/` for operator
recovery, but they are no longer mounted or used by the automatic SSL feature.

## Manual TLS Remains Separate

Manual/imported/self-signed certificates are still supported with
`TLS_ENABLED=true` and `ACME_ENABLED` disabled. Stage a combined private key and
full chain at:

```text
configs/ssl/server.pem
```

Then rotate it into active storage:

```sh
./scripts/ssl/rotate-ssl-and-restart-haproxy.sh
```

That helper keeps three active PEM backups and restarts only HAProxy. It refuses
automatic mode and symlinked paths. It is a manual certificate rotation tool, not
an ACME deploy hook, and it does not validate certificate trust or provide
transactional rollback on restart failure.

## Verification Status

Local tests used disposable containers, synthetic credentials and a local Pebble
ACME CA. No production deployment was launched or restarted, no real private
state was inspected, no authenticated MyAddr update was made, and no public CA
order was requested.

Tests cover adapter validation, wrapper behavior, Docker and rootless Podman
smoke behavior, initial DNS-01 issuance, requested renewal, expired-PEM renewal
at startup, persistence, served certificate, recreation and CA-outage retention.
See [tests/ssl/README.md](../tests/ssl/README.md).

Remaining rollout gate: use an explicitly authorized MyAddr test registration
and staging ACME state to verify authenticated MyAddr updates, authoritative DNS
propagation and due renewal. Keep staging material separate from production
storage.

## Primary Sources

Checked 2026-09-15:

- HAProxy native ACME guide: https://www.haproxy.com/documentation/haproxy-configuration-tutorials/security/ssl-tls/acme/
- HAProxy Data Plane API exec provider: https://github.com/haproxytech/dataplaneapi/blob/v3.4.3/acme/exec/provider.go
- HAProxy Debian s6 image: https://github.com/haproxytech/haproxy-docker-debian/tree/main/3.4
- MyAddr API: https://myaddr.tools/
- Let's Encrypt challenge types: https://letsencrypt.org/docs/challenge-types/
- Certbot 3.0.0 release notes: https://github.com/certbot/certbot/releases/tag/v3.0.0
- Docker Compose restart behavior: https://docs.docker.com/reference/cli/docker/compose/restart/
