# What's this

This is a db-less alternative implementation for the [cardano-token-registry] server which uses the official repository json files as source of truth instead of populating a postgres db for it.

# Run

* Install depends:

```
git clone https://github.com/cardano-foundation/cardano-token-registry
npm i
```
* Run the server:
```
npm run start
```

## Run using docker

You can run it using docker and specifying a custom `cardano-token-registry` git clone:

```
CARDANO_TOKEN_REGISTRY_DIR=$HOME/Projects/cardano-token-registry

docker run -it --rm \
  -v ${CARDANO_TOKEN_REGISTRY_DIR}:/app/cardano-token-registry \
  -p 3042:3042 \
  gimbalabs/dbless-cardano-token-registry:latest
```


[cardano-token-registry]: https://github.com/cardano-foundation/cardano-token-registry
