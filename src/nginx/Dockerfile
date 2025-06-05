ARG NGINX_IMAGE

# Stage 1: Generate .htpasswd using a utility image
FROM alpine:latest AS htpasswd-generator

RUN apk add --no-cache apache2-utils


ARG NGINX_WWW_BACKUP_USER
ARG NGINX_WWW_BACKUP_PASSWORD
ENV NGINX_WWW_BACKUP_USER=${NGINX_WWW_BACKUP_USER}
ENV NGINX_WWW_BACKUP_PASSWORD=${NGINX_WWW_BACKUP_PASSWORD}
#TODO: add admin user and password for logs access and other info

RUN mkdir -p /output && \
    htpasswd -bc /output/.htpasswd "$NGINX_WWW_BACKUP_USER" "$NGINX_WWW_BACKUP_PASSWORD"

# Create webroot folder for certbot
RUN mkdir -p /usr/share/nginx/ssl

# Stage 2: Final nginx image
FROM "${NGINX_IMAGE}"

LABEL maintainer="dandelion"

# Copy htpasswd file
COPY --from=htpasswd-generator /output/.htpasswd /etc/nginx/.htpasswd

# Expose default port (can be overridden via Compose)
EXPOSE 8800
