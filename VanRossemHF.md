# Van Rossem Hard Fork accumulative update

## Runtime Split

The official Intersect `cardano-node` container is used in its `NETWORK`-driven mode, matching Intersect `cardano-node` and `cardano-db-sync` Docker Compose examples. Dandelion does not pass `cardano-node run --config ...` into this image because that image has its own generated runtime wrapper/config.


Particular situations with Ogmios team maintainance on last hard forks/critical updates are forcing us to decouple Ogmios from Cardano Node, a bundle shipped by Ogmios team.

Dandelion now runs Cardano node and Ogmios as separate services: `cardano-node` and `cardano-ogmios`. Public ports and HAProxy routes remain stable. Internal dependencies now point node consumers to `cardano-node` and Ogmios consumers to `cardano-ogmios`.

Env examples use canonical `CARDANO_NODE_*` and `CARDANO_OGMIOS_*` variables. `CARDANO_GRAPHQL_OGMIOS_URI` remains only because Cardano GraphQL MKII expects that env var.

## Image Targets

```env
CARDANO_NODE_VERSION=11.0.1
CARDANO_OGMIOS_VERSION=v6.14.0.1
CARDANO_DB_SYNC_VERSION=13.7.1.0
CARDANO_SUBMIT_API_VERSION=11.0.1
BLOCKFROST_VERSION=6.5.0
```

Currently Ogmios uses a local dockerfile that will be published as `ghcr.io/gamechangerfinance/ogmios:${CARDANO_OGMIOS_VERSION}` as there is no official Ogmios image published yet on any registry and we are 4 days close to the HF event. `src/cardano-ogmios/Dockerfile` builds it from the official Intersect Ogmios `v6.14.0.1` Linux tarball.

## Network Configs

Mainnet, preprod, and preview Cardano node configs were refreshed from the official Cardano Operations Book where available. Preview also has `.env.example.preview`, marked untested. Peer snapshots are read-only config artifacts under `configs/cardano/config/network/<network>/cardano-node/peer-snapshot.json`.

Sanchonet was left untouched because the checked official config URLs returned 404. Have been moved?.

## Healthchecks

`cardano-node` health follows the official Intersect Compose pattern and checks the node EKG endpoint on `127.0.0.1:12788`. It no longer blocks startup on sync percentage.


`cardano-ogmios` health uses Ogmios health tooling when available and falls back to `GET /health` on the internal Ogmios port.

## SSL And Certbot

HAProxy now reads only the active PEM from:

```text
secrets/ssl/server.pem
```

Cron/Certbot writes the candidate PEM to:

```text
configs/ssl/server.pem
```

Added `scripts/ssl/rotate-ssl-and-restart-haproxy.sh` to promote the candidate PEM into `secrets/ssl/server.pem`, keep `.old.1` to `.old.3` backups, and restart only HAProxy. `dandoman.sh` now exposes setup actions for Certbot renewal and SSL rotation.

`src/cron/Dockerfile` now installs `certbot`. Certbot renewal state is persisted under `secrets/letsencrypt/` and mounted only into the cron container. dandoman can also create a self-signed PEM candidate at `configs/ssl/server.pem` using `scripts/ssl/keygen.sh`; operators must rotate it before HAProxy uses it.

## Backup Sync

`scripts/docker/full-backup-sync.sh` now self-heals missing Compose volumes before downloading backups by reading `docker compose config --volumes` and creating missing project-prefixed volumes with `docker volume create`.

## Docs

Updated `README.md`, `configs/README.md`, `secrets/README.md`, dandoman help, and generated education docs for the split services, peer snapshots, SSL staging/rotation, Certbot state, self-signed candidates, and current HAProxy certificate path.

## Static Verification

Shell syntax checks passed for the edited shell scripts. Repo-wide static searches were run for stale bundled node/Ogmios identifiers and stale HAProxy SSL mount paths; remaining SSL path references describe the intended active secret path or temporary Certbot candidate path. This is a first commit, WIP.
