import json
import subprocess
import time
import uuid
import tempfile
from pathlib import Path

def run(*args, check=True):
    p = subprocess.run(['docker', *args], capture_output=True, text=True)
    if check and p.returncode:
        raise RuntimeError('Container operation failed: ' + args[0] + ': ' + p.stderr[-600:])
    return p

def main():
    root = Path(__file__).resolve().parents[2]
    run('build', '-t', 'localhost/dandelion-pgadmin-test:9.19', str(root / 'src/pgadmin'))
    fixture = Path(tempfile.mkdtemp(prefix='dandelion-pgadmin-fixture-'))
    secret = fixture / 'password'
    secret.write_text('fixture-only-password')
    secret.chmod(0o600)
    name = 'dandelion-pgadmin-audit-' + uuid.uuid4().hex[:8]
    db, app = name + '-db', name + '-app'
    try:
        run('network', 'create', '--internal', name)
        run('run', '-d', '--name', db, '--network', name, '--network-alias', 'fixture-postgres',
            '--tmpfs', '/var/lib/postgresql', '-e', 'POSTGRES_USER=fixture',
            '-e', 'POSTGRES_DB=fixture', '-e', 'POSTGRES_PASSWORD=fixture-only-password',
            'docker.io/library/postgres:18.7-bookworm')
        for _ in range(60):
            if run('exec', db, 'pg_isready', '-U', 'fixture', check=False).returncode == 0:
                break
            time.sleep(1)
        run('run','-d','--name',app,'--network',name,
            '-e','NETWORK=fixture', '-e','POSTGRES_HOST=fixture-postgres',
            '-e','POSTGRES_DB=fixture','-e','POSTGRES_USER=fixture',
            '-e','POSTGRES_PASSWORD_FILE=/run/secrets/db-password',
            '-e','PGADMIN_DISABLE_POSTFIX=1', '-e','PGADMIN_LISTEN_PORT=8080',
            '-v',str(secret)+':/run/secrets/db-password:ro',
            '--tmpfs','/pgpass:mode=0700',
            'localhost/dandelion-pgadmin-test:9.19')
        probe = "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8080/browser/',timeout=3); print(r.status, '/login' not in r.url)"
        for _ in range(90):
            p=run('exec',app,'/venv/bin/python3','-c',probe,check=False)
            if p.returncode==0:
                print('Desktop UI, no login redirect:',p.stdout.strip(),flush=True)
                break
            time.sleep(1)
        else:
            raise RuntimeError('pgAdmin UI did not become ready')
        readable="import os; print(os.getuid(),os.access('/pgpass/pgpass',os.R_OK))"
        assert run('exec',app,'su-exec','5050:0','/venv/bin/python3','-c',readable).stdout.strip() == '5050 True'
        web_connect = """from run_pgadmin import app
from itsdangerous import URLSafeTimedSerializer
client=app.test_client()
assert client.get('/browser/').status_code==200
with client.session_transaction() as session:
    session['csrf_token']='fixture-csrf'
key=app.config.get('WTF_CSRF_SECRET_KEY') or app.secret_key
token=URLSafeTimedSerializer(key,salt='wtf-csrf-token').dumps('fixture-csrf')
r=client.post('/browser/server/connect/1/1',json={},headers={'X-pgA-CSRFToken':token})
assert r.status_code==200, r.status_code
d=r.get_json()
assert d.get('success')==1 and d.get('data',{}).get('connected') is True, d.get('errormsg','Connection did not succeed')
print('PASS: desktop web connection without a database password prompt')
"""
        p=run('exec','-w','/pgadmin4',app,'su-exec','5050:0','/venv/bin/python3','-c',web_connect)
        print(p.stdout.strip(),flush=True)
        connect="import psycopg; c=psycopg.connect(host='fixture-postgres',port=5432,dbname='fixture',user='fixture',passfile='/pgpass/pgpass',connect_timeout=5); print(c.execute('SELECT 1').fetchone()[0]); c.close()"
        print('Automatic DB authentication SELECT 1:',run('exec',app,'su-exec','5050:0','/venv/bin/python3','-c',connect).stdout.strip(),flush=True)
        catalog="import sqlite3; c=sqlite3.connect('/var/lib/pgadmin/pgadmin4.db'); print(c.execute('SELECT count(*) FROM server').fetchone()[0])"
        print('Imported server registrations:',run('exec',app,'su-exec','5050:0','/venv/bin/python3','-c',catalog).stdout.strip(),flush=True)
        # Reuse the existing pgAdmin settings database while rotating the runtime secret.
        run('exec',db,'psql','-U','fixture','-d','fixture','-v','ON_ERROR_STOP=1','-c',
            "ALTER ROLE fixture PASSWORD 'rotated:fixture\\password'")
        secret.write_text('rotated:fixture\\password')
        run('restart',app)
        for _ in range(90):
            p=run('exec',app,'/venv/bin/python3','-c',probe,check=False)
            if p.returncode==0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('pgAdmin did not restart')
        assert run('exec',app,'su-exec','5050:0','/venv/bin/python3','-c',connect).stdout.strip() == '1'
        p=run('exec','-w','/pgadmin4',app,'su-exec','5050:0','/venv/bin/python3','-c',web_connect)
        print(p.stdout.strip(),flush=True)
        print('PASS: existing settings, restart and rotated colon/backslash password',flush=True)
        logs=run('logs',app)
        assert 'fixture-only-password' not in logs.stdout+logs.stderr
        assert 'rotated:fixture' not in logs.stdout+logs.stderr
    finally:
        for target in (app,db):
            run('rm','-f',target,check=False)
        run('network','rm',name,check=False)

if __name__ == '__main__':
    main()
