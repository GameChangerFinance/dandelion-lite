# SSL Operation And Migration

## Goal

Keep optional SSL simple: HAProxy owns automated MyAddr issuance, renewal,
activation and persistence. Cron continues updating the dynamic IP, but has no
certificate storage, HAProxy control socket or Docker socket.

For the complete automatic ACME design, MyAddr exec adapter behavior, security
boundary and reasons the old Certbot lifecycle was removed, read
[Native ACME With MyAddr](ACME.md).

## Choose A Mode

`TLS_ENABLED` in `.env` is the protocol selection point. It controls only the
existing HAProxy port mapping; it does not add or change ports.

| Mode | Configuration | Certificate lifecycle |
| --- | --- | --- |
| Automatic MyAddr TLS | `TLS_ENABLED=true`, `ACME_ENABLED=true`, matching `MYADDR_DOMAIN` and `MYADDR_TOKEN` | Native HAProxy ACME, no recurring manual rotation |
| Manual/imported/self-signed TLS | `TLS_ENABLED=true`, `ACME_ENABLED` empty or false | Operator supplies and rotates the PEM |
| Plaintext | `TLS_ENABLED` empty or false | No certificate required or ACME order started |

Automatic settings in `.env`:

```env
TLS_ENABLED=true
ACME_ENABLED=true
MYADDR_DOMAIN=your-registration-label
MYADDR_TOKEN=your-registration-token
```

The certificate covers `your-registration-label.myaddr.io`, not the equivalent
`.tools` or `.dev` names. The token must belong to that registration.
No Certbot executable is used. The manual CLI flag is
`--ssl-renew`. Old Certbot-prefixed names are not compatibility aliases.

Missing automatic credentials with `ACME_ENABLED=true` stop startup with an
operator-facing error. Manual TLS with no `secrets/ssl/server.pem` also stops
startup. Fresh automatic mode needs no pre-generated PEM, but usable TLS depends
on successful issuance.

## Network Requirements

DNS-01 does **not** require any additional public port, port 80, or port 443.
Keep the operator-selected `HAPROXY_PORT`. The ingress guest needs outbound HTTPS
to MyAddr and the ACME CA, plus working DNS resolution and access to authoritative
DNS for the companion's propagation checks. MyAddr publishes a temporary TXT
record; HAProxy's official companion waits for DNS propagation.

Issuance can work behind CGNAT. Public API access is separate: the selected
ingress port must be reachable from clients through the operator's chosen
network arrangement. A certificate or DDNS update cannot remove CGNAT.

## Implementation And Private State

The pinned HAProxy Technologies image contains HAProxy 3.4.4, Data Plane API
3.4.3, s6, curl and socat. No additional language runtime is installed. Native
ACME is experimental upstream. The small exec adapter is
`scripts/ssl/myaddr-acme.sh`; it posts encoded `key` and `acme_challenge` fields,
checks HTTP 200 / `OK`, and never puts the token in process arguments. Its delete
callback is deliberately a no-op: MyAddr expires TXT records automatically;
HTTP DELETE would remove the IP records.

Host `secrets/ssl/` is mounted only into ingress at `/var/lib/haproxy/ssl/`:

- `server.pem`: active certificate, chain and private key; native renewals replace it.
- `myaddr.account.key`: persistent native ACME account key.
- `server.pem.old.1` through `.old.3`: backups created only by manual rotation.

**Security requirement: keep `secrets/ssl` mode `0700`.** The pinned official
companion explicitly writes combined PEMs with mode `0644`, overriding umask.
The owner-only parent directory prevents other users from traversing it and
reading those keys. This is an approved directory access boundary, not a claim
that the PEM itself is mode `0600`. On normal service startup, the entrypoint
logs and sets `0700` on that exact mounted directory, verifies the mode, and
refuses symlinked storage/certificate/account paths. It does not recursively
chmod, chown, or delete operator files. Permission errors stop startup.

Do not relax that directory's permissions while ingress is running. Preserve
the restriction when restoring backups; protect exported PEM copies separately
with `0600`. A future upstream file-mode fix should be verified before removing
this protection. [Pinned storage implementation](https://github.com/haproxytech/client-native/blob/v6.4.2/storage/storage.go).

The image's master and companion run as container root to read existing private
files and persist replacements; HAProxy workers drop to the image's `haproxy`
user. Rootless Podman maps container root to the operator's user namespace; do
not apply arbitrary host UID ownership changes to work around access failures.
The local management sockets live in the container, are owner-only, and are
never mounted into cron or published on TCP. Data Plane API has no usable login.
This isolates management from other services, not from an attacker who already
controls ingress container root. MyAddr's registration token remains powerful
DNS authority and is also needed by the separate DDNS updater.

Host routing configuration is read-only. Startup makes disposable private copies
for both processes because Data Plane API writes its own config and a last-known-good
HAProxy config. The checked-in host configuration remains authoritative on every
container restart. There is no file watcher, additional renewal scheduler,
certificate promotion script, or ingress restart on automatic renewal.

## Migration

Review and run these steps yourself during an approved maintenance window;
implementation tests do not deploy this stack.

Rename `CERTBOT_ENABLED` to `ACME_ENABLED`
in existing `.env` files and external automation, preserving their values.
Replace `--ssl-certbot-renew` with `--ssl-renew` in command invocations.
This is an intentional interface change: the old names are no longer read.
1. Back up `secrets/ssl/` privately. Leave `secrets/letsencrypt/` intact for recovery;
   native HAProxy does not import or mount old Certbot account state.
2. Merge the new TLS block and companion config into any customized HAProxy config.
   Public routes and the Compose ingress port mapping are unchanged. Plaintext
   now uses `TLS_ENABLED` empty/false, rather than editing bind lines.
3. Select a mode and set `.env`. Native propagation checks replace the fixed
   delay. In automatic mode the
   DDNS updater ignores legacy `MYADDR_ACME_CHALLENGE` to avoid conflicting TXT updates.
4. Rebuild and recreate **only** the changed guests (cron still runs the other jobs):

```sh
docker compose build haproxy cron
docker compose up -d --no-deps --force-recreate haproxy cron
docker compose logs --tail 100 haproxy
```

Recreation is required for the new image, directory mount and environment.
`docker compose restart` alone does not apply changed `.env` values or mounts.
No host-side cron is required. The retired Certbot cron entry is removed when
cron rebuilds its crontab from the source fragments.

If enabling automatic mode with an existing unexpired self-signed certificate,
or changing `MYADDR_DOMAIN`, request renewal **once** after migration:

```sh
./scripts/dandoman.sh --ssl-renew
```

Native scheduling uses certificate lifetime, not issuer trust or a comparison
against a previous configured domain. Without that one-time request, an existing
long-lived self-signed PEM can postpone issuance. Fresh empty storage issues
automatically. Subsequent renewals are unattended; do not schedule the manual
renew command or run it repeatedly against production CA rate limits.

## Status And Recovery

From the deployment host:

```sh
docker compose exec -T haproxy /scripts/ssl/haproxy-acme.sh status
docker compose exec -T haproxy /scripts/ssl/haproxy-acme.sh renew
docker compose logs --tail 100 haproxy
```

The dandoman menu action is `Setup > Renew Automatic SSL`; the
`--ssl-renew` flag delegates to the same guest helper. `renew` acknowledges
an asynchronous request, not completed issuance. `status` reports the native
schedule/state. Check logs for provider, DNS, CA and certificate-storage errors;
also check the certificate actually served to clients. Runtime status alone does
not prove persistence succeeded.

A failed ACME attempt does not replace the last usable certificate. An expired
certificate still causes client failures: monitor expiry and logs. If storage
fails after runtime activation, repair the directory's permissions/space and
request renewal again; do not assume an in-memory certificate survived recreation.

## Manual Certificates

Set `TLS_ENABLED=true`, leave `ACME_ENABLED` disabled and recreate ingress before switching from
automatic ownership to manual ownership. Self-signing remains explicit:

```sh
./scripts/dandoman.sh --ssl-self-signed your-domain
./scripts/ssl/rotate-ssl-and-restart-haproxy.sh
```

For imported certificates, put the combined private key and full chain in
`configs/ssl/server.pem`, then use the same rotation command. It retains three
backups and restarts only HAProxy. Rotation refuses enabled automatic mode and
symlinked paths. It remains a manual tool, not an ACME deploy hook; validate an
imported PEM before using it. It does not provide automatic rollback on restart
failure. To bootstrap manual TLS without an already-running ingress, supply the
active `secrets/ssl/server.pem` before starting ingress.

## Verification Limits

The reproducible tests are documented in [tests/ssl/README.md](../tests/ssl/README.md).
Local Pebble tests use no public CA or MyAddr credentials. As in HAProxy's upstream
fixture, they bypass the companion's SOA/NS propagation probe because Pebble's
test DNS server does not implement it; Pebble still checks the challenge TXT.
Authenticated MyAddr issuance and real authoritative propagation require a
separately authorized test registration and staging CA. They are not implied by
local test success.

Sources checked 2026-09-15: [native ACME](https://www.haproxy.com/documentation/haproxy-configuration-tutorials/security/ssl-tls/acme/),
[official image](https://github.com/haproxytech/haproxy-docker-debian/tree/main/3.4),
[exec provider](https://github.com/haproxytech/dataplaneapi/blob/v3.4.3/acme/exec/provider.go),
[MyAddr API](https://myaddr.tools/),
[Let's Encrypt challenges](https://letsencrypt.org/docs/challenge-types/).

See [Native ACME With MyAddr](ACME.md) for the consolidated design and removal
rationale for the old Certbot flow.
