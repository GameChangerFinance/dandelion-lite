#!/bin/bash
source .env

docker build \
    --platform linux/amd64 \
    --build-arg CARDANO_OGMIOS_VERSION="${CARDANO_OGMIOS_VERSION}" \
    --build-arg CARDANO_OGMIOS_ARCH=x86_64-linux \
    -t "ghcr.io/gamechangerfinance/ogmios:${CARDANO_OGMIOS_VERSION}" \
    -f src/cardano-ogmios/Dockerfile \
    src/cardano-ogmios

docker run --rm ghcr.io/gamechangerfinance/ogmios:v6.14.0.2 --version

#docker login ghcr.io -u GameChangerFinance
#docker push ghcr.io/gamechangerfinance/ogmios:v6.14.0.2