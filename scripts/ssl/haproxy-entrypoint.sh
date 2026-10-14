#!/bin/sh
set -eu

# Protect new private state and local management sockets, including s6 children.
umask 077
if [ "$#" -eq 0 ]; then
    ssl=/var/lib/haproxy/ssl
    secure_ssl_file() {
        file=$1
        [ -e "$file" ] || return 0
        if [ -L "$file" ] || [ ! -f "$file" ]; then
            echo "Refusing to protect unsafe SSL state path: $file" >&2
            return 1
        fi
        mode=$(stat -c %a "$file")
        if [ "$mode" != 600 ]; then
            chmod 0600 "$file" || return 1
            echo "Protected $(basename "$file") with owner-only file permissions (0600)."
        fi
    }
    secure_ssl_state() {
        if [ "$(stat -c %a "$ssl")" != 700 ]; then
            echo 'Protecting secrets/ssl with owner-only directory permissions (0700).'
            chmod 0700 "$ssl" || {
                echo 'Cannot secure secrets/ssl. Fix directory ownership for the ingress container; do not make keys public.' >&2
                return 1
            }
        fi
        [ "$(stat -c %a "$ssl")" = 700 ] || return 1
        secure_ssl_file "$ssl/server.pem"
        secure_ssl_file "$ssl/myaddr.account.key"
    }
    start_ssl_permission_guard() {
        (
            last_cert_id=
            while :; do
                secure_ssl_state
                if [ -s "$ssl/server.pem" ]; then
                    cert_id=$(stat -c '%s:%Y' "$ssl/server.pem")
                    if [ "$cert_id" != "$last_cert_id" ]; then
                        if expiry=$(openssl x509 -in "$ssl/server.pem" -noout -enddate 2>/dev/null); then
                            expiry=${expiry#notAfter=}
                            if [ "${TLS_ENABLED:-}" = true ] && [ "${ACME_ENABLED:-}" = true ]; then
                                echo "✅ Automatic SSL certificate is persisted, protected with 0600, and valid until $expiry."
                            else
                                echo "✅ TLS certificate is present, protected with 0600, and valid until $expiry."
                            fi
                        else
                            echo '❌ TLS certificate exists but is not a readable X.509 PEM.' >&2
                        fi
                        last_cert_id=$cert_id
                    fi
                fi
                sleep 5
            done
        ) &
    }
    # DPA 3.4.3 writes PEMs with mode 0644, regardless of umask. This fixed,
    # owner-only directory is the primary access boundary; never chmod recursively.
    if [ ! -d "$ssl" ] || [ "$(readlink -f "$ssl")" != "$ssl" ] \
        || [ -L "$ssl/server.pem" ] || [ -L "$ssl/myaddr.account.key" ]; then
        echo 'SSL storage must be a real directory with regular certificate/account files; symlinks are not supported.' >&2
        exit 1
    fi
    secure_ssl_state || exit 1
    if [ "${TLS_ENABLED:-}" = true ]; then
        if [ "${ACME_ENABLED:-}" = true ]; then
            if [ -z "${MYADDR_TOKEN:-}" ] || [ -z "${MYADDR_DOMAIN:-}" ]; then
                echo 'TLS_ENABLED=true and ACME_ENABLED=true require MYADDR_TOKEN and MYADDR_DOMAIN. Fix .env and recreate ingress.' >&2
                exit 1
            fi
            echo "ℹ️ Automatic SSL is enabled; HAProxy will issue/renew ${MYADDR_DOMAIN}.myaddr.io using native ACME."
        elif [ ! -s "$ssl/server.pem" ]; then
            echo 'TLS_ENABLED=true with ACME disabled requires secrets/ssl/server.pem. Provide a manual PEM, enable ACME, or set TLS_ENABLED=false for plaintext.' >&2
            exit 1
        else
            echo 'ℹ️ Manual TLS is enabled; HAProxy will use secrets/ssl/server.pem.'
        fi
    fi
    # The companion saves its config and an HAProxy .lkg on startup.
    # These runtime copies are disposable; the host configs stay authoritative.
    cp /usr/local/etc/haproxy/dataplaneapi.yml /var/lib/dataplaneapi/dataplaneapi.yml
    cp /usr/local/etc/haproxy/haproxy.cfg /var/lib/dataplaneapi/haproxy.cfg
    start_ssl_permission_guard
fi
exec /start.sh "$@"
