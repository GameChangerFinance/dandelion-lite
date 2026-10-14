# SSL And Native ACME

## Goal

Keep optional TLS simple: HAProxy owns automatic MyAddr ACME issuance, renewal,
activation and persistence. Cron updates only the dynamic IP; it has no certificate
storage, HAProxy control socket or container-engine authority.

This is the single source of truth for SSL behavior, migration, security and
operator workflows in Dandelion Lite.

## Choose A Mode

`TLS_ENABLED` selects the protocol on the existing HAProxy port; it never adds or
changes a published port.

| Mode | Configuration | Certificate lifecycle |
| --- | --- | --- |
| Automatic MyAddr TLS | `TLS_ENABLED=true`, `ACME_ENABLED=true`, matching `MYADDR_DOMAIN` and `MYADDR_TOKEN` | HAProxy native ACME owns issuance, renewal, activation and persistence |
| Manual/custom TLS | `TLS_ENABLED=true`, `ACME_ENABLED` empty or false | Operator provides the active PEM and restarts HAProxy |
| Plaintext | `TLS_ENABLED` empty or false | No certificate is required |

Automatic settings in `.env`:

```env
TLS_ENABLED=true
ACME_ENABLED=true
MYADDR_DOMAIN=your-registration-label
MYADDR_TOKEN=your-registration-token
```

The certificate covers `your-registration-label.myaddr.io`, not an equivalent
`.tools` or `.dev` name. Missing automatic credentials stop ingress startup with
an actionable error. In manual mode, a missing active PEM also stops startup.

## Operator Actions

`scripts/dandoman.sh` exposes three SSL actions. Each state-changing action shows
what it will do and waits for Enter; use Ctrl-C to cancel before it changes state.

| Action | CLI | Result |
| --- | --- | --- |
| Create Self-Signed SSL and Apply | `--ssl-self-signed <domain-or-common-name>` | Replaces `secrets/ssl/server.pem` and restarts HAProxy. It is allowed in automatic mode as temporary TLS. |
| Renew Automatic SSL and Apply | `--ssl-renew` | Requests native renewal. HAProxy applies a successful certificate dynamically; it does not restart. |
| Check SSL Status | `--ssl-status` | Shows mode, safe credential readiness, active-PEM presence and native ACME status without printing secrets or PEM contents. |

Self-signed certificates are temporary in automatic mode. After applying one,
request renewal when MyAddr credentials and connectivity are ready so HAProxy can
replace it with the managed certificate.

## Automatic MyAddr ACME

HAProxy native ACME and its official Data Plane API companion request, renew,
apply and persist the certificate directly at `secrets/ssl/server.pem`. The
persistent ACME account key is `secrets/ssl/myaddr.account.key`.

Fresh automatic storage issues without a pre-existing PEM. When migrating with a
long-lived self-signed certificate or changing `MYADDR_DOMAIN`, request renewal
once because native scheduling follows certificate lifetime rather than migration
state:

```sh
./scripts/dandoman.sh --ssl-renew
```

Routine renewal is unattended. Do not schedule or repeatedly invoke `--ssl-renew`;
unnecessary requests can consume CA rate limits. HAProxy has no Dandelion cron
interval: its native task schedules renewal from certificate expiration.

The authoritative schedule is available through:

```sh
docker compose exec -T haproxy /scripts/ssl/haproxy-acme.sh status
```

`Running` means an issuance/renewal task is active, `Scheduled` means a usable
certificate has a future renewal time, and `Stopped` means no task is scheduled.

## MyAddr DNS-01 Adapter

`scripts/ssl/myaddr-acme.sh` is called only by the HAProxy Data Plane API ACME
exec provider, never by cron. It accepts the expected DNS-01 TXT challenge for
`_acme-challenge.${MYADDR_DOMAIN}.myaddr.io`.

For `set` and `append`, it sends encoded `key` and `acme_challenge` values to
MyAddr over HTTPS. The token is passed through stdin rather than process
arguments. Success requires HTTP 200 and body `OK`; requests are time-bounded,
TLS verification remains enabled, and response bodies are not disclosed.

For `delete`, the adapter returns success without an HTTP request. MyAddr expires
temporary TXT challenges automatically; its DELETE endpoint would remove dynamic
IP records. The separate MyAddr cron updater continues updating the public IP and
suppresses the legacy static TXT value in automatic mode.

DNS-01 does not require port 80, port 443, or another inbound challenge port.
Ingress needs outbound HTTPS to MyAddr and the ACME CA plus working DNS and
authoritative propagation visibility. Issuance can work behind CGNAT; public API
reachability remains the operator's separate network concern.

## Private State And Security

Only ingress mounts `secrets/ssl/`, at `/var/lib/haproxy/ssl/`. Keep the host
directory mode `0700`. The pinned Data Plane API persistence implementation can
write PEMs as `0644`; the owner-only parent directory is the primary protection.
The ingress entrypoint rejects symlinked storage, certificate and account-key
paths and continuously tightens the two private files to `0600`.

HAProxy workers drop privileges, while the container master and companion remain
root to read and replace private material. Their management sockets are local,
owner-only Unix sockets, never mounted into cron or exposed on TCP. Protect any
exported PEM separately with `0600`.

The checked-in HAProxy configuration remains read-only. Startup makes disposable
private copies because the companion writes configuration and a last-known-good
HAProxy file. There is no host-side certificate scheduler or automatic HAProxy
restart during ordinary ACME renewal.

## Custom Certificates

For a custom certificate, create one combined PEM containing the private key and
full certificate chain, then place it directly at `secrets/ssl/server.pem` with
owner-only permissions and restart HAProxy:

```sh
install -m 0600 /secure/path/to/server.pem secrets/ssl/server.pem
docker compose restart haproxy
```

Set `TLS_ENABLED=true` and leave `ACME_ENABLED` disabled when the custom
certificate should remain under manual control. Recreate ingress—not just
restart it—after changing `.env`, image or mounts:

```sh
docker compose up -d --no-deps --force-recreate haproxy
```

The self-signed dandoman action may be used even while automatic ACME is enabled,
but automatic ACME can later replace that temporary PEM. No SSL certificate backup
or rotation workflow exists.

## Migration From Certbot

The Certbot workflow was removed because it split issuance from the ingress that
serves TLS. Cron could create a candidate but could not safely activate it; giving
cron HAProxy or Docker control would expand the compromise boundary. Native ACME
keeps issuance, renewal, activation and persistence inside ingress.

During migration:

1. Rename `CERTBOT_ENABLED` to `ACME_ENABLED`; old Certbot names are unsupported.
2. Replace `--ssl-certbot-renew` with `--ssl-renew`.
3. Back up existing `secrets/ssl/` privately. Old `secrets/letsencrypt/` state is
   not imported or mounted by native ACME.
4. Rebuild and recreate ingress and cron after this migration:

   ```sh
   docker compose build haproxy cron
   docker compose up -d --no-deps --force-recreate haproxy cron
   docker compose logs --tail 100 haproxy
   ```

## Status And Recovery

Start with:

```sh
./scripts/dandoman.sh --ssl-status
docker compose logs --tail 100 haproxy
```

The dandoman status action does not print credentials or PEM contents. A renewal
request is asynchronous: inspect the status, HAProxy logs and the certificate
served to clients. A failed ACME attempt retains the last usable certificate, but
an expired certificate still causes client failures. If persistence fails after
runtime activation, repair permissions or disk space and request renewal again.

## Verification Limits

The reproducible checks are documented in [tests/ssl/README.md](../tests/ssl/README.md).
They use synthetic credentials and a local Pebble CA; they do not prove authenticated
MyAddr updates, authoritative propagation, public-CA issuance, elapsed-time due
renewal or a production upgrade. Those need an explicitly authorized staging
registration and maintenance window.

Sources checked 2026-09-15: [HAProxy native ACME](https://www.haproxy.com/documentation/haproxy-configuration-tutorials/security/ssl-tls/acme/),
[HAProxy image](https://github.com/haproxytech/haproxy-docker-debian/tree/main/3.4),
[Data Plane API exec provider](https://github.com/haproxytech/dataplaneapi/blob/v3.4.3/acme/exec/provider.go),
[MyAddr API](https://myaddr.tools/) and [Let's Encrypt challenge types](https://letsencrypt.org/docs/challenge-types/).
