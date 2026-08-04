# Custom Postgres image with Cardano-related extensions
# Extensions: pg_cardano (enabled), pg_curl (disabled for now)

FROM postgres:18.2-bookworm

ARG PG_CARDANO_VERSION=v1.2.0
ARG PGRX_VERSION=0.17.0

# ---- Build deps (needed only at build time) ----
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    make \
    build-essential \
    pkg-config \
    clang \
    llvm-dev \
    libclang-dev \
    libssl-dev \
    postgresql-server-dev-$PG_MAJOR \
 && rm -rf /var/lib/apt/lists/*

# ---- Rust toolchain (needed to build pg_cardano via pgrx) ----
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --default-toolchain stable

RUN cargo install cargo-pgrx --version ${PGRX_VERSION} --locked

# ---- Build & install pg_cardano ----
RUN git clone --branch ${PG_CARDANO_VERSION} --depth 1 \
      https://github.com/cardano-community/pg_cardano.git /tmp/pg_cardano \
 && cargo pgrx init --pg${PG_MAJOR} "$(command -v pg_config)" \
 && cd /tmp/pg_cardano \
 && cargo pgrx install --release --features pg${PG_MAJOR} \
 && rm -rf /tmp/pg_cardano

# ---- pg_curl (DISABLED) ----
# SECURITY NOTE: enabling pg_curl allows outbound network access from inside Postgres.
# Only enable if you intentionally want that capability and you fully trust every SQL role
# that can CREATE FUNCTION / EXECUTE pg_curl functions.
#
# To enable, uncomment the block below and rebuild.
#
# RUN apt-get update \
#  && apt-get install -y --no-install-recommends libcurl4-openssl-dev \
#  && rm -rf /var/lib/apt/lists/*
#
# RUN git clone https://github.com/RekGRpth/pg_curl.git /tmp/pg_curl_ext
# COPY pg_curl/Makefile /tmp/pg_curl_ext/Makefile
# RUN make -C /tmp/pg_curl_ext PG_CONFIG="$(command -v pg_config)" \
#  && make -C /tmp/pg_curl_ext install PG_CONFIG="$(command -v pg_config)" \
#  && rm -rf /tmp/pg_curl_ext

# ---- Cleanup build-time deps & toolchains ----
RUN rm -rf $RUSTUP_HOME $CARGO_HOME \
 && apt-get purge -y --auto-remove \
    git \
    make \
    build-essential \
    pkg-config \
    clang \
    llvm-dev \
    libclang-dev \
    libssl-dev \
    postgresql-server-dev-$PG_MAJOR \
 && rm -rf /var/lib/apt/lists/* /tmp/*

# Extensions can be created at init-time if you want them enabled by default.
# (Keep disabled unless you know what you're doing.)
# RUN echo "CREATE EXTENSION IF NOT EXISTS pg_cardano;" >> /docker-entrypoint-initdb.d/10_extensions.sql
# RUN echo "CREATE EXTENSION IF NOT EXISTS pg_curl;" >> /docker-entrypoint-initdb.d/10_extensions.sql
