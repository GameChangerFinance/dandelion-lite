# Dandelion Lite Secrets

Private runtime state belongs here, never in Git. Do not commit keys, tokens,
account material or backups containing them.

## SSL

Ingress alone mounts `secrets/ssl/` at `/var/lib/haproxy/ssl/`.

- `server.pem`: active combined private key and certificate chain.
- `myaddr.account.key`: persistent native ACME account key.
- `server.pem.old.1` through `.old.3`: manual rotation backups.

**Keep this directory owner-only (`0700`).** Ingress enforces that mode at
startup and rejects symlinked storage/certificate/account paths. Data Plane API
3.4.3 writes PEMs as `0644` despite umask; the private directory is therefore
the primary access boundary. The ingress entrypoint also tightens `server.pem`
and `myaddr.account.key` to `0600` when they exist and keeps those exact files
protected while ingress runs. Do not relax directory permissions while ingress is
running. Protect exported copies separately with `0600`. Ownership is not
automatically changed. See [permission details and migration](../docs/ssl.md) and
[Native ACME With MyAddr](../docs/ACME.md).

## Automatic MyAddr TLS

Set `TLS_ENABLED=true`, `ACME_ENABLED=true`, `MYADDR_DOMAIN` (registration label,
no suffix), and its matching `MYADDR_TOKEN` in `.env`.

HAProxy obtains, renews and applies the certificate automatically, saving it
directly here. No candidate, host cron or routine manual rotation is involved.
Changing environment or migrating the mount/image requires container recreation;
a restart alone does not apply those changes.

From the host:

```sh
docker compose exec -T haproxy /scripts/ssl/haproxy-acme.sh status
./scripts/dandoman.sh --ssl-renew
docker compose logs --tail 100 haproxy
```

The renewal command requests asynchronous work. Read the [SSL guide](../docs/ssl.md)
and [ACME guide](../docs/ACME.md) for first-start behavior and migration from an
existing self-signed certificate.

## Manual TLS

Keep automation disabled. Create a candidate with
`./scripts/dandoman.sh --ssl-self-signed <domain-or-common-name>`, or stage an
imported combined PEM at `configs/ssl/server.pem`. Apply it with:

```sh
./scripts/ssl/rotate-ssl-and-restart-haproxy.sh
```

This retains three previous active PEMs and restarts only HAProxy. No candidate
means no rotation. Manual rotation is not the automatic renewal path.
