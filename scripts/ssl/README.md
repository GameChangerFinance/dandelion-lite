# SSL Helpers

SSL behavior, operator workflows and migration guidance are centralized in
[docs/ssl.md](../../docs/ssl.md).

| Script | Scope | Purpose |
| --- | --- | --- |
| `myaddr-acme.sh` | Ingress callback | Official exec-provider contract; TXT updates only |
| `haproxy-entrypoint.sh` | Ingress startup | Enforce private storage and invoke upstream s6 startup |
| `haproxy-acme.sh status\|renew` | Inside ingress | Inspect native state or request asynchronous issuance/renewal |
| `keygen.sh <domain> <file-prefix>` | Host | Create a validated self-signed PEM |
| `create-self-signed-ssl-and-apply.sh` | Host | Create an active self-signed PEM and restart HAProxy |
| `check-ssl-status.sh` | Host | Report safe TLS, PEM and native ACME status |

Run each helper with `--help` for its interface. Never run the callback with
production tokens for testing.
