# Use Alpine Linux as the base image
FROM alpine:latest

# Install jq, curl, PostgreSQL client, and gawk
RUN apk add --no-cache jq curl postgresql-client gawk git bash

# Set up the cron job environment
# Create a directory for cron jobs
RUN mkdir -p /etc/cron.d

# Copy your cron job files
COPY ./scripts/cron/* /etc/cron.d/

# Give execution rights on the cron job and create the log file
RUN chmod 0644 /etc/cron.d/* && touch /var/log/cron.log

# Run the command on container startup
CMD ["/scripts/cron/entrypoint.sh"]
