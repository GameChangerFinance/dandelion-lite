# Dandelion Lite Secrets

This directory is for operator-managed secrets and private runtime state. Do not commit real keys, certificates, tokens, or Certbot account material.

## SSL

HAProxy reads the active TLS certificate from:

```text
secrets/ssl/server.pem
```

`configs/ssl/server.pem` is only a temporary candidate location. Certbot and manual workflows write there first. The candidate is not active until it is rotated into `secrets/ssl/server.pem`.

### Enable Certbot Cron

1. Set these values in `.env`:

```env
CERTBOT_ENABLED=true
MYADDR_DOMAIN=<your-myaddr-subdomain-without-.myaddr.io>
MYADDR_TOKEN=<your-myaddr-token>
CERTBOT_EMAIL=<optional-email>
CERTBOT_DNS_PROPAGATION_SECONDS=60
```

2. Recreate or restart the cron container on the deployment host so it receives the updated env.
3. Certbot cron output is written to `logs/cron/myaddrdns_certbot.log`.
4. When a new `configs/ssl/server.pem` candidate exists, rotate it with:

```sh
./scripts/ssl/rotate-ssl-and-restart-haproxy.sh
```

The same rotation is available from `scripts/dandoman.sh` under `Setup` > `Rotate SSL and Restart HAProxy`.

### Manually Try Certbot

From the deployment host, with `.env` loaded by dandoman or the shell:

```sh
./scripts/dandoman.sh --ssl-certbot-renew
```

Or from the dandoman menu:

```text
Setup > Check/Renew SSL Candidate
```

That command writes the candidate PEM to `configs/ssl/server.pem`. It does not restart HAProxy and does not change `secrets/ssl/server.pem` until rotation is run.

### Create A Self-Signed Candidate

From dandoman:

```text
Setup > Create Self-Signed SSL Candidate
```

Or from the CLI:

```sh
./scripts/dandoman.sh --ssl-self-signed <domain-or-common-name>
```

This creates `configs/ssl/server.pem` using `scripts/ssl/keygen.sh`. To apply it, run:

```sh
./scripts/ssl/rotate-ssl-and-restart-haproxy.sh
```

### Rotate And Apply

Rotation moves the candidate into the active secret path:

```text
configs/ssl/server.pem -> secrets/ssl/server.pem
```

The previous active PEM is backed up under `secrets/ssl/` as:

```text
server.pem.old.1
server.pem.old.2
server.pem.old.3
```

After moving the PEM, the rotation script restarts only the `haproxy` service using Docker Compose.

## Certbot State

Certbot account, renewal, and live certificate state is stored under:

```text
secrets/letsencrypt/
```

This path is mounted only into the cron container at `/etc/letsencrypt/`. It is intentionally separate from `configs/ssl/`, which is just the temporary PEM handoff directory.
