#!/bin/sh
set -eu
umask 077
/install_pgpass.sh
# The upstream entrypoint requires a bootstrap password even in desktop mode.
# Desktop users still enter without a login or master-password prompt.
if [ -z "${PGADMIN_DEFAULT_PASSWORD:-}" ] && [ -z "${PGADMIN_DEFAULT_PASSWORD_FILE:-}" ]; then
    PGADMIN_DEFAULT_PASSWORD=$(/venv/bin/python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
    export PGADMIN_DEFAULT_PASSWORD
fi
exec /entrypoint.sh "$@"
