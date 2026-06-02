FROM debian:bookworm-slim

ARG CARDANO_OGMIOS_VERSION=v6.14.0.1
ARG CARDANO_OGMIOS_ARCH=x86_64-linux

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl libgmp10 libnuma1 \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
    "https://github.com/IntersectMBO/ogmios/releases/download/${CARDANO_OGMIOS_VERSION}/ogmios-${CARDANO_OGMIOS_VERSION}-${CARDANO_OGMIOS_ARCH}.tar.gz" \
    -o /tmp/ogmios.tar.gz \
  && tar -xzf /tmp/ogmios.tar.gz -C /usr/local/bin \
  && rm /tmp/ogmios.tar.gz \
  && chmod +x /usr/local/bin/ogmios

EXPOSE 1337
ENTRYPOINT ["ogmios"]
