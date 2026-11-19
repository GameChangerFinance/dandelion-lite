#!/bin/sh
# Prepare private connection files at startup; never bake credentials into images.
set -eu
umask 077

/venv/bin/python3 - <<'PY'
import json
import os
from pathlib import Path


def main():
    required = ('NETWORK', 'POSTGRES_DB', 'POSTGRES_USER')
    for name in required:
        if not os.environ.get(name):
            raise SystemExit(f'Missing {name}; provide the PostgreSQL connection settings at runtime.')
    password_file = os.environ.get('POSTGRES_PASSWORD_FILE')
    password = Path(password_file).read_text().rstrip('\r\n') if password_file else os.environ.get('POSTGRES_PASSWORD', '')
    if not password:
        raise SystemExit('Provide POSTGRES_PASSWORD_FILE or POSTGRES_PASSWORD at runtime.')
    directory = Path('/pgpass')
    if directory.is_symlink() or directory.resolve() != directory:
        raise SystemExit('Refusing unsafe pgAdmin connection directory: /pgpass')
    directory.mkdir(mode=0o700, exist_ok=True)
    uid, gid = int(os.environ.get('PUID', '5050')), int(os.environ.get('PGID', '0'))
    if uid <= 0 or gid < 0:
        raise SystemExit('PUID must be a non-root UID and PGID must be non-negative.')
    host = os.environ.get('POSTGRES_HOST', 'postgress')
    fields = (host, '5432', os.environ['POSTGRES_DB'], os.environ['POSTGRES_USER'], password)
    if any('\n' in value or '\r' in value for value in fields):
        raise SystemExit('PostgreSQL passfile fields must not contain line breaks.')
    escaped = [value.replace('\\', '\\\\').replace(':', '\\:') for value in fields]
    servers = {'Servers': {'1': {
        'Group': 'Servers', 'Name': os.environ['NETWORK'], 'Host': host, 'Port': 5432,
        'MaintenanceDB': os.environ['POSTGRES_DB'], 'Username': os.environ['POSTGRES_USER'],
        'Favorite': True, 'ConnectionParameters': {'sslmode': 'prefer', 'connect_timeout': 10,
                                                   'passfile': '/pgpass/pgpass'}}}}
    for name, content in [('pgpass', ':'.join(escaped) + '\n'), ('servers.json', json.dumps(servers))]:
        path = directory / name
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise SystemExit(f'Refusing unsafe pgAdmin connection file: {path}')
        with path.open('w') as stream:
            stream.write(content)
        os.chmod(path, 0o600)
        os.chown(path, uid, gid)
    os.chmod(directory, 0o700)
    os.chown(directory, uid, gid)


if __name__ == '__main__':
    main()
PY
