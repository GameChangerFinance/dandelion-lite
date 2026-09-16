# SSL Helpers

Automatic MyAddr SSL is native HAProxy ACME. Read the
[operator and migration guide](../../docs/ssl.md) and
[ACME design notes](../../docs/ACME.md), especially the required owner-only
`secrets/ssl` directory permissions.

| Script | Scope | Purpose |
| --- | --- | --- |
| `myaddr-acme.sh` | Ingress callback | Official exec-provider contract; TXT updates only |
| `haproxy-entrypoint.sh` | Ingress startup | Enforce private storage, copy runtime config, invoke upstream s6 startup |
| `haproxy-acme.sh status\|renew` | Inside ingress | Inspect native state or request asynchronous issuance/renewal |
| `keygen.sh <domain> <file-prefix>` | Host | Existing explicit self-signing helper |
| `rotate-ssl-and-restart-haproxy.sh` | Host | Manual certificate rotation only, with three backups |

From the host:

```sh
docker compose exec -T haproxy /scripts/ssl/haproxy-acme.sh status
./scripts/dandoman.sh --ssl-renew
```

The dandoman renewal flag invokes native ACME. Successful request submission is
not completed issuance; inspect status, logs and the served cert.
Run each helper with `--help` for its interface (the existing `keygen.sh` takes
positional arguments). Never run the callback with production tokens for testing.
