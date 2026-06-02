# Dandelion Lite Configs

This directory contains configuration files mounted into Dandelion Lite services. Keep service-owned runtime data out of this tree unless it is meant to be a checked-in or operator-managed config artifact.

## Blockfrost

`blockfrost/` contains Blockfrost RYO static config inputs, currently including genesis files mounted into the Blockfrost container at `/app/config/genesis`.

The active Blockfrost runtime YAML is generated from the `blockfrost_config` Docker Compose config in `docker-compose.yml`, using the `BLOCKFROST_CONFIG_*` environment variables from `.env`.

## Haproxy

`haproxy/` contains the public routing layer for Dandelion Lite.

Important files:

- `haproxy.cfg`: maps public paths such as `/ogmios`, `/cardano-graphql-mk2`, `/blockfrost/api/v0`, `/cardano-submit-api`, `/koios`, and `/postgrest` to internal Docker services.
- `origin-whitelist.map` and `ip-blacklist.lst`: request filtering inputs used by HAProxy.

When internal service names change, update only backend targets in `haproxy.cfg`. Public paths should stay stable unless a breaking API migration is intentionally planned.

## SSL

`ssl/` is a temporary input location for certificate renewal workflows. It is mounted read/write only into the cron container at `/data/ssl/`.

Active HAProxy certificates are not read from `configs/ssl/`. HAProxy reads the active PEM from:

```text
secrets/ssl/server.pem
```

The certbot/MyAddr cron workflow and manual renewal workflows write the candidate PEM to:

```text
configs/ssl/server.pem
```

To activate a candidate certificate, run from the repository root:

```sh
./scripts/ssl/rotate-ssl-and-restart-haproxy.sh
```

The same action is available in `scripts/dandoman.sh` under `Setup` > `Rotate SSL and Restart HAProxy`.

Rotation behavior:

- moves `configs/ssl/server.pem` to `secrets/ssl/server.pem`
- backs up the previous active cert as `secrets/ssl/server.pem.old.1`
- shifts older backups up to `.old.3`
- restarts only the `haproxy` service with Docker Compose

If there is no `configs/ssl/server.pem`, the rotation script exits without changing HAProxy.

Cron certbot logs are written to `logs/cron/myaddrdns_certbot.log`. Operators should check that log for renewal activity and then rotate the candidate PEM when ready.

Certbot account and renewal state is stored under `secrets/letsencrypt/` and mounted only into the cron container at `/etc/letsencrypt/`. Do not move that state into `configs/ssl/`; `configs/ssl/` is only the temporary PEM handoff directory.

## Cardano

`cardano/` contains Cardano network configuration mounted into node-adjacent services. The active layout is:

```text
cardano/config/network/<network>/cardano-node/
cardano/config/network/<network>/cardano-db-sync/
```

`cardano-node/` files are mounted read-only into `cardano-node` and `cardano-ogmios` at `/config`. `cardano-db-sync/` files are mounted read-only into `cardano-db-sync` at `/config/cardano-db-sync` through the same network config root.

### Updating Official Network Configs

Use the official Cardano Operations Book environment files as the source of truth:

- Environments index: https://book.world.dev.cardano.org/environments.html
- Mainnet files: https://book.world.dev.cardano.org/environments/mainnet/
- Preprod files: https://book.world.dev.cardano.org/environments/preprod/
- Preview files: https://book.world.dev.cardano.org/environments/preview/
- Developer Portal topology reference: https://developers.cardano.org/docs/get-started/infrastructure/node/topology/

For each supported network, refresh the Cardano node files from the matching environment directory:

```sh
NETWORK=mainnet
BASE="https://book.world.dev.cardano.org/environments/${NETWORK}"
DEST="configs/cardano/config/network/${NETWORK}/cardano-node"

curl -fsSL "${BASE}/config.json" -o "${DEST}/config.json"
curl -fsSL "${BASE}/topology.json" -o "${DEST}/topology.json"
curl -fsSL "${BASE}/byron-genesis.json" -o "${DEST}/byron-genesis.json"
curl -fsSL "${BASE}/shelley-genesis.json" -o "${DEST}/shelley-genesis.json"
curl -fsSL "${BASE}/alonzo-genesis.json" -o "${DEST}/alonzo-genesis.json"
curl -fsSL "${BASE}/conway-genesis.json" -o "${DEST}/conway-genesis.json"
```

If the official `config.json` references extra files, fetch those too. For example mainnet may reference:

```sh
curl -fsSL "${BASE}/checkpoints.json" -o "${DEST}/checkpoints.json"
```

Keep these files as read-only config artifacts. Do not solve node write errors by making the config mount writable or by putting config artifacts in shared IPC volumes.

### Peer Snapshots

`peer-snapshot.json` is used by `cardano-node` topology in Ouroboros Genesis / trustless sync mode. It contains a snapshot of large ledger peers that helps a node discover useful peers when starting from a blank or stale chain state. Once the node ledger state is newer than the snapshot, the node can ignore it for normal operation.

The file is not secret and does not need the same backup treatment as `node-db`, `postgresdb`, or `db-sync-data`. It is still an input config artifact: if `topology.json` references it, it must exist when the node starts.

Dandelion keeps peer snapshots beside topology files and mounts them read-only:

```text
configs/cardano/config/network/<network>/cardano-node/peer-snapshot.json
```

Topology should reference it as a local config file:

```json
"peerSnapshotFile": "peer-snapshot.json"
```

Do not put peer snapshots in `node-ipc`; that volume is only for the node socket shared with dependent services.

#### Update From Official Source

```sh
NETWORK=mainnet
BASE="https://book.world.dev.cardano.org/environments/${NETWORK}"
DEST="configs/cardano/config/network/${NETWORK}/cardano-node"

curl -fsSL "${BASE}/peer-snapshot.json" -o "${DEST}/peer-snapshot.json"
```

Repeat for `preprod` and `preview` when those networks are maintained in the repo.

#### Update From A Running Instance

For a self-sovereign refresh, generate the snapshot from a fully synced trusted node and then replace the config artifact before restarting `cardano-node`:

```sh
cardano-cli query ledger-peer-snapshot \
  --out-file peer-snapshot.json
```

Inside Dandelion, run that command from a context that has `cardano-cli` and access to the node socket. Write the result outside shared IPC, review it, then place it at:

```text
configs/cardano/config/network/<network>/cardano-node/peer-snapshot.json
```

Restart `cardano-node` after replacing the file so the topology input is reloaded.
