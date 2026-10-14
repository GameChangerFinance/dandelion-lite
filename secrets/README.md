# Dandelion Lite Secrets

Private runtime state belongs here, never in Git. Do not commit keys, tokens,
account material or backups containing them.

## SSL

Ingress alone mounts `secrets/ssl/` at `/var/lib/haproxy/ssl/`. Active certificate
and ACME account state live here; keep the directory owner-only (`0700`). The
complete TLS workflow and permission requirements are in [docs/ssl.md](../docs/ssl.md).
