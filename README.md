<!-- ![Example Image](images/Koios.png) -->

```
___  ____ __ _ ___  ____ _    _ ____ __ _
|__> |--| | \| |__> |=== |___ | [__] | \|
                                   lite
```
# Dandelion Lite

Dandelion is a community-supported project led by GimbaLabs and operated by La PEACEpool Cardano repsist₳nce. Every Cardano API available. From bottom to top, from testnet to mainnet.

Dandelion Lite is a convenient way of deploying your own local Cardano Node and a set of Dandelion APIs. It uses docker-compose, podman and handy scripts to ease the setup and reduce node syncronization times by using volume snapshots for backup and restore procedures. Dandelion Lite is a fork of Koios Lite, extending it beyond Koios, created by GameChanger Finance and M2Tec teams.

## Components

This setup includes several key components:

- `cardano-node-ogmios`: Runs the Cardano node plus the lightweight bridge interface Ogmios.
- `cardano-db-sync`: Synchronizes the blockchain data to a PostgreSQL database.
- `haproxy`: A high-performance proxy to distribute network traffic among various components.
- `postgres`: The PostgreSQL database, storing the synchronized blockchain data.
- `koios`: RESTful API for Cardano, based on PostGREST. 
- `cardano-graphql`: Official GraphQL API for Cardano.
- `cardano-token-registry`: Official Token Registry API for Cardano.
- `dandelion-postgrest`: Dandelion PostGREST API for Cardano, a RESTful API for querying the blockchain data stored in PostgreSQL
- `cardano-sql`: PosgreSQL-over-HTTP API gateway wrapping several services such as
    - ogmios
    - cardano-db-sync
    - cardano-graphql
    - koios
    - dandelion-postgrest
    - cardano-token-registry
    - more..
- `manifest`: JSON information of deployed Dandelion Lite Node, required for client applications and for joining the Dandelion Network of decentralized nodes
- `home`: HTML landing website of deployed Dandelion Lite Node 

Each service is containerized and managed via Docker, ensuring easy deployment and scalability.

## Hardware Requirements (13-09-2024):

Suggested setup for concurrent **Cardano Mainnet** and **Preproduction Testnet** consists on

- 128GB RAM (DDR4 ECC RAM)
- 2TB M2 NVME for storage
- Dual Intel Xeon E5 2680 v4 (LGA 2011-3 motherboard)

### Cardano Mainnet volume sizes


    25G     /home/$USER/.local/share/containers/storage/volumes/gc-node-mainnet_db-sync-data
    445M    /home/$USER/.local/share/containers/storage/volumes/gc-node-mainnet_dbless-cardano-token-registry-data
    185G    /home/$USER/.local/share/containers/storage/volumes/gc-node-mainnet_node-db
    8.0K    /home/$USER/.local/share/containers/storage/volumes/gc-node-mainnet_node-ipc
    518G    /home/$USER/.local/share/containers/storage/volumes/gc-node-mainnet_postgresdb
    8.0K    /home/$USER/.local/share/containers/storage/volumes/gc-node-mainnet_unimatrix-data

### Cardano Pre-Production Testnet volume sizes

    3.7G    /home/$USER/.local/share/containers/storage/volumes/gc-node-preprod_db-sync-data
    41M     /home/$USER/.local/share/containers/storage/volumes/gc-node-preprod_dbless-cardano-token-registry-data
    8.4G    /home/$USER/.local/share/containers/storage/volumes/gc-node-preprod_node-db
    8.0K    /home/$USER/.local/share/containers/storage/volumes/gc-node-preprod_node-ipc
    15G     /home/$USER/.local/share/containers/storage/volumes/gc-node-preprod_postgresdb
    8.0K    /home/$USER/.local/share/containers/storage/volumes/gc-node-preprod_unimatrix-data

## Deployment

Base system install:
As a base system we use ubuntu-server version 24.04. We use the normal install not the minimal one. Also install OpenSSH server to allow for system administration. 
1. When install do `ip -br a` to get the ip address of your newly installed server 
2. From you local system. So not on your server do `ssh-copy-id username@server-ip` This will copy your ssh keys to the server to allow easy login
3. Do `ssh username@server-ip`

To deploy or run Dandelion Lite:
1. Clone the repository to your local machine.
2. Run `./scripts/dandoman.sh --podman-install` to install podman. Exit the terminal and log back in.
3. Run Admin Tool `scripts/dandoman.sh` for setting up an initial `.env` file and installing dependencies such as Docker Compose and Podman. Exit the gui and restart your terminal
4. Edit/configure the environment variables the `.env` file. You can base it on the provided `env.example.<NETWORK>`.
5. Run `scripts/dandoman.sh` > `Docker->Docker Up/Reload` on Admin Tool or `docker compose up -d` to start the services.
6. Monitor that node has reached tip and `scripts/dandoman.sh` > `Docker->Docker Status` to ensure none of the containers are `DOWN` or `UP (unhealthy)` state.
7. Once on tip, execute `scripts/dandoman.sh` > `Setup->Initialise Postgres` to deploy custom RPCs and test via PostgREST/HAProxy endpoints using curl:

```bash
# Check if the node is synced using docker
docker inspect --format "{{json .State.Health }}" dandolite-preprod-cardano-node-ogmios-1 | jq

# Check if db-sync is ready 
docker inspect --format "{{json .State.Health }}" dandolite-preprod-cardano-db-sync-1 | jq

# Koios tip check
curl http://127.0.0.1:8050/koios/v1/tip
```

Remember to secure your deployment according to best practices, including securing your database and API endpoints.


## Admin tool
A simple script to interact with the all the components of a Dandelion Lite Node:
[Admin Tool Documentation](AdminTool.md)

```bash
>scripts/dandoman.sh --help

Dandelion Lite Administration Tool Help Menu:
------------------------------------

Welcome to the Dandelion Lite Administration Tool Help Menu.

Below are the available commands and their descriptions:

--about: 			     Displays information about the Koios administration tool.
--install-dependencies:  Installs necessary dependencies.
--check-docker: 		 Checks if Docker is running.
--handle-env-file: 		 Manage .env file.
--reset-env: 			 Resets the .env file to defaults.
--docker-status: 		 Shows the status of Docker containers.
--docker-up: 			 Starts Docker containers defined in docker compose.yml.
--docker-down: 			 Stops Docker containers defined in docker compose.yml.
--enter-node: 			 Accesses the Cardano Node container.
--logs-node: 			 Displays logs for the Cardano Node container.
--gliveview: 			 Executes gLiveView in the Cardano Node container.
--cntools: 			     Runs CNTools in the Cardano Node container.
--enter-postgres: 		 Accesses the Postgres container.
--logs-postgres: 		 Displays logs for the Postgres container.
--enter-dbsync: 		 Accesses the DBSync container.
--logs-dbsync: 			 Displays logs for the DBSync container.
--enter-haproxy: 		 Accesses the HAProxy container.
--logs-haproxy: 		 Displays logs for the HAProxy container.
```
