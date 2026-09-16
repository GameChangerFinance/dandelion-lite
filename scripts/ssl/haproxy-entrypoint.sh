#!/bin/sh
set -eu

# Protect new private state and local management sockets, including s6 children.
umask 077
if [ "$#" -eq 0 ]; then
    # DPA 3.4.3 writes PEMs with mode 0644, regardless of umask. This fixed,
    # owner-only directory is the access boundary; never chmod recursively.
    ssl=/var/lib/haproxy/ssl
    if [ ! -d "$ssl" ] || [ "$(readlink -f "$ssl")" != "$ssl" ] \
        || [ -L "$ssl/server.pem" ] || [ -L "$ssl/myaddr.account.key" ]; then
        echo 'SSL storage must be a real directory with regular certificate/account files; symlinks are not supported.' >&2
        exit 1
    fi
    if [ "$(stat -c %a "$ssl")" != 700 ]; then
        echo 'Protecting secrets/ssl with owner-only directory permissions (0700).'
        chmod 0700 "$ssl" || {
            echo 'Cannot secure secrets/ssl. Fix directory ownership for the ingress container; do not make keys public.' >&2
            exit 1
        }
    fi
    [ "$(stat -c %a "$ssl")" = 700 ] || exit 1
    # The companion saves its config and an HAProxy .lkg on startup.
    # These runtime copies are disposable; the host configs stay authoritative.
    cp /usr/local/etc/haproxy/dataplaneapi.yml /var/lib/dataplaneapi/dataplaneapi.yml
    cp /usr/local/etc/haproxy/haproxy.cfg /var/lib/dataplaneapi/haproxy.cfg
fi
exec /start.sh "$@"
