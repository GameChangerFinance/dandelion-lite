FROM dpage/pgadmin4:9.19@sha256:3591b3d02910dcd817dec6fcaa681c278ba6966945283dd0ea0042731c330c83

# Root prepares private files; the official entrypoint drops to PUID (5050).
USER root
ENV PGADMIN_SERVER_JSON_FILE=/pgpass/servers.json \
    PGADMIN_CONFIG_SERVER_MODE=False \
    PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=False \
    PGADMIN_DEFAULT_EMAIL=testing@example.io
COPY install_pgpass.sh /install_pgpass.sh
COPY entrypoint.sh /dandelion-entrypoint.sh
RUN chmod 0755 /install_pgpass.sh /dandelion-entrypoint.sh
ENTRYPOINT ["/dandelion-entrypoint.sh"]
EXPOSE 80
