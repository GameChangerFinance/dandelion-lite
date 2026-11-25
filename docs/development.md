# Development tools and local API access

Dandelion Lite exposes a shared Cardano service stack for application development and integration testing. Use the optional `admin` profile to add administration tools without making them part of every deployment. The profile currently contains **pgAdmin only**; commented Portainer and Swagger services are not enabled out-of-the-box by this profile (yet).

## Prerequisites and project selection

Run commands from the repository root with a configured `.env` and a working Compose provider. The examples use `docker compose`, including installations where Docker commands are provided by Podman. The provider must support profiles and environment-backed Compose secrets.

Use the same environment file and project identity as the running stack. If you selected another environment file, include it consistently, for example `docker compose --env-file .env.preprod --profile admin up -d`. Replace that example filename with your actual file.

Complete the normal [deployment setup](../README.md#deployment) first. pgAdmin waits for the `postgress` service to be healthy, but that does not mean db-sync has reached tip or that application SQL/RPC initialization has completed. Use the setup workflow in the README when schemas or RPCs are missing.

## Start and stop the admin tools

Start the normal stack without opting into development tools:

```sh
docker compose up -d
```

Start the stack together with the tools in `admin`:

```sh
docker compose --profile admin up -d
```

To add only pgAdmin to an already running stack:

```sh
docker compose --profile admin up -d --no-deps pgadmin
docker compose ps pgadmin
docker compose port pgadmin 80
```

Use `--no-deps` only when PostgreSQL is already running and healthy. Omit it to let Compose start the declared database dependency. Explicitly targeting `pgadmin` also activates that service without needing `--profile admin`; it does not start every other service in the project.

Stop just pgAdmin and keep its container and settings:

```sh
docker compose stop pgadmin
```

Start its existing container again with `docker compose start pgadmin`. Stop and remove only the tool's container with `docker compose rm --stop pgadmin`; its named settings volume is retained.

**Do not use `docker compose --profile admin down` to stop only the tools.** It also stops and removes services without a profile, including the main stack. Profiles select optional services; they are not separate Compose projects. Likewise, a project-wide `stop` is not restricted to tools merely by enabling `admin`. See the [Compose profile behavior](https://docs.docker.com/compose/how-tos/profiles/).

`COMPOSE_PROFILES=admin` can enable the profile persistently through your shell or `.env`. Without that setting, a plain `up -d` does not start pgAdmin automatically. Removing the setting or omitting the flag does not itself stop an already running tool: use the explicit `stop pgadmin` command. The service has `restart: always`, so an enabled container can restart independently of a later Compose command's profile selection.

## pgAdmin: automatic access and persistent settings

Open the localhost address reported by `docker compose port pgadmin 80`, using HTTP. For example, if it reports `127.0.0.1:15051`, open `http://127.0.0.1:15051`. The actual port comes from `PGADMIN_PORT`; Compose falls back to `5050` when it is unset. The supplied environment examples set network-specific values instead.

pgAdmin uses desktop mode: there is no pgAdmin login or master-password prompt. On first initialization, it imports a server named after `NETWORK`, targeting `POSTGRES_HOST` on the internal database port `5432`. Selecting that server connects using the runtime password file without asking you to enter the PostgreSQL password.

The connection grants the permissions of the configured `POSTGRES_USER`. It is access to the actual db-sync database, not a disposable copy. Prefer read-only queries for inspection:

```sql
BEGIN READ ONLY;
SELECT current_database(), version();
SELECT block_no, time FROM public.block ORDER BY id DESC LIMIT 1;
ROLLBACK;
```

The second query requires an initialized db-sync database. For destructive experiments, use a separate disposable database/deployment. Follow the [backup and restore guide](backups.md) before changing valuable data.

The `pgadmin-data` volume stores pgAdmin registrations and preferences; blockchain data remains in `postgresdb`. Private connection files are regenerated in the `/pgpass` tmpfs on each start, using the Compose `postgres_password` secret. They have owner-only permissions for pgAdmin's runtime UID. Database credentials are not build arguments and are not baked into the image.

Existing settings are retained. Server definitions are imported on first initialization rather than replacing your saved registrations on every restart. If you change the database host, username or database name, update an existing registration in pgAdmin to match; the generated passfile remains `/pgpass/pgpass`.

After updating the password source, apply the new runtime secret by recreating only pgAdmin:

```sh
docker compose --profile admin up -d --no-deps --force-recreate pgadmin
```

The PostgreSQL role's password must already match the new secret. Changing `.env` alone does not change an existing database role's password. A plain container restart also does not apply new Compose environment values. Do not remove volumes to resolve a password or registration mismatch.

## Host ports versus container ports

Host tools connect through a published host port. Containers on the Compose network connect through service DNS names and internal ports. For example, a host PostgreSQL client uses `127.0.0.1` and `POSTGRES_PORT`, while pgAdmin uses `POSTGRES_HOST` and **5432**, regardless of the published host port. The database Compose service is spelled **`postgress`**.

Discover the effective mappings without printing credentials:

```sh
docker compose ps
docker compose port postgress 5432
docker compose port haproxy 8053
docker compose port pgadmin 80
```

| Service | Host port setting | Internal port | Development use |
| --- | --- | ---: | --- |
| HAProxy | `HAPROXY_PORT` | 8053 | Integrated API routes, manifest and ingress behavior |
| PostgreSQL (`postgress`) | `POSTGRES_PORT` | 5432 | SQL clients, queries and database inspection |
| Ogmios | `CARDANO_OGMIOS_PORT` | `CARDANO_OGMIOS_INTERNAL_PORT` (normally 1337) | Direct HTTP health and WebSocket requests |
| GraphQL MKII | `CARDANO_GRAPHQL_PORT` | 4000 | Direct GraphQL requests |
| Koios PostgREST | `POSTGREST_PORT` | 8050 | Direct RPC requests |
| Dandelion PostgREST | `DANDELION_POSTGREST_PORT` | Listener 8060 | See the mapping limitation below |
| Blockfrost | `BLOCKFROST_PORT` | `BLOCKFROST_CONFIG_SERVER_PORT` (normally 8055) | Direct REST requests |
| Submit API | `CARDANO_SUBMIT_API_PORT` | 8090 | Transaction submission; this can submit real transactions |
| Unimatrix | `UNIMATRIX_PORT` | 8765 | Relay and WebSocket integration |
| NGINX | `NGINX_PORT` | 8800 | Direct backup serving; authentication required |
| pgAdmin (`admin` profile) | `PGADMIN_PORT` | 80 | Browser database administration; localhost only |

**Current mapping limitation:** Dandelion PostgREST listens on internal port `8060`, but its published mapping targets `8050`. Its direct host port can therefore fail even while `/postgrest/` through HAProxy works. Use the ingress route until that mapping is corrected; do not change the database connection or credentials to troubleshoot this particular failure.

The supplied examples use `PORT_OFFSET` values `0`, `1` and `2` for mainnet, preprod and preview. Most host ports concatenate that prefix with a service suffix: preprod PostgreSQL is `15432` and pgAdmin is `15051`. HAProxy uses `308${PORT_OFFSET}` instead, giving preprod `3081`. These are strings, not arithmetic offsets. Different deployments need distinct project names, port allocations and database volumes; use separate working directories for independent network configurations.

## Direct API debugging and remote access

Use HAProxy routes to test the behavior clients see, including routing, TLS, CORS and rate limits. Use a direct backend port to isolate an application or inspect its native endpoint. Direct access does not exercise ingress protections or path rewriting. For example, `/blockfrost/api/v0/health` at ingress maps to `/health` on Blockfrost; `/cardano-graphql-mk2/graphql` maps to `/graphql` on GraphQL MKII. Keep the request path appropriate to the endpoint.

Most backend mappings publish on host interfaces by default. This supports local and authorized LAN/VPN development, but is not a firewall policy. pgAdmin is explicitly bound to `127.0.0.1` because it opens without authentication. For public exposure, tunneling and host firewall requirements, follow [SECURITY.md](../SECURITY.md#host-firewall-and-external-access). For protocol selection and certificates, follow [TLS operations](ssl.md).

To access pgAdmin on a remote host without publishing it publicly, forward its loopback port over SSH. For a remote pgAdmin port of `15051`, run this on your workstation, replacing the SSH target:

```sh
ssh -N -L 15051:127.0.0.1:15051 operator@your-server
```

Then open `http://127.0.0.1:15051` on your workstation. Select another local port if it is already occupied. Anyone able to reach this forwarded interface receives the configured database access; do not add pgAdmin to a public tunnel or ingress route without an appropriate access boundary.

## Troubleshooting and regression checks

| Symptom | Check |
| --- | --- |
| pgAdmin does not start with the main stack | Enable `admin` or explicitly target `pgadmin`; check `COMPOSE_PROFILES`. |
| Browser cannot connect | Check `docker compose ps -a pgadmin`, `docker compose logs --tail=50 pgadmin` and the actual published port. Remote browsers need a tunnel. |
| PostgreSQL dependency is unhealthy | Inspect `docker compose logs --tail=50 postgress`; do not delete the database volume. |
| Missing secret or runtime connection settings | Check the selected `.env`, `POSTGRES_PASSWORD` secret source and provider support for environment-backed secrets. Keep values out of shared logs. |
| Database password prompt | Confirm the saved registration's host, database, username and passfile path match the current runtime settings. Recreate pgAdmin after changing the secret source. |
| Empty or missing blockchain/RPC data | Check node/db-sync progress and SQL initialization; database readiness alone is not chain synchronization. |

For a SQL terminal without installing a PostgreSQL client on the host:

```sh
docker compose exec postgress sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Validate Compose without starting services, and run the isolated pgAdmin regression test when changing its integration:

```sh
docker compose --profile admin config --quiet
python3 tests/pgadmin/check.py
```

The test needs Python 3 and the container engine. It builds the pgAdmin test image and starts disposable pgAdmin/PostgreSQL containers on an internal network, with synthetic credentials and no published host ports. It checks desktop access, the web connection endpoint, persisted settings across restart and password rotation. It does not test migration of an older pgAdmin settings volume. For ingress changes, use the checks described in [tests/ssl/README.md](../tests/ssl/README.md).
