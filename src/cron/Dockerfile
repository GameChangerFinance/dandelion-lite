# Use Alpine Linux as the base image
FROM alpine:latest

ARG CARDANO_NODE_VERSION=10.1.4

# Install jq, curl, PostgreSQL client, and gawk b2sum (coreutils) and tini
RUN apk add --no-cache jq curl postgresql-client gawk git bash coreutils tini

# Set up the cron job environment
# Create a directory for cron jobs
# RUN mkdir -p /etc/cron.d

# Copy your cron job files
# COPY ./scripts/cron/* /etc/cron.d/

# Give execution rights on the cron job and create the log file
# RUN chmod 0644 /etc/cron.d/* && touch /var/log/cron.log
RUN touch /var/log/cron.log



# install minimal deps, grab and extract cardano-cli, then clean up
RUN apk add --no-cache ca-certificates curl tar gzip \
     && curl -sL \
          https://github.com/input-output-hk/cardano-node/releases/download/${CARDANO_NODE_VERSION}/cardano-node-${CARDANO_NODE_VERSION}-linux.tar.gz \
          | tar xz \
               --wildcards \
               --no-anchored \
               --strip-components=2 \
               -C /usr/local/bin \
               'bin/cardano-cli' \
     && chmod +x /usr/local/bin/cardano-cli 

# curl tar gzip are used by cron job scripts, do not remove.

# tini as PID 1 to reap orphaned children, otherwise this saturate OS with zombie processes
ENTRYPOINT ["/sbin/tini", "--"]

# Run the command on container startup
CMD ["/scripts/cron/entrypoint.sh"]