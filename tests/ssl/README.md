# SSL Regression Checks

Run from the repository root:

```sh
bash tests/ssl/unit.sh
bash tests/ssl/scripts-check.sh
bash tests/ssl/container-check.sh
bash tests/ssl/acme-check.sh
bash tests/ssl/podman-check.sh
```

Requirements: Bash, Git history containing baseline `8452d05`, standard shell tools, curl, jq, OpenSSL, tar and sha256sum; Docker for container tests and rootless Podman for the last check. No packages are installed. Container-check builds the pinned image with only its Dockerfile and entrypoint as context. Run it before the ACME/Podman checks, which reuse the image. ACME tests download verified Linux amd64 Pebble 2.8.0 binaries.

| Check | Coverage |
| --- | --- |
| unit | Callback validation, encoded requests, missing credentials, provider errors/timeouts, no token in arguments/output, safe cleanup, helper usage |
| scripts-check | Fixture rotation, automatic-mode refusal, symlinks, dandoman failure propagation, isolated wizard choices, DDNS challenge isolation, generated cron, unchanged HAProxy route/default sections |
| container-check | Full configuration parsing, manual HTTPS/plaintext manifest, plaintext renewal refusal, API 401, socket/directory permissions, unprivileged PEM access denial, empty-store automatic parsing |
| acme-check | Local DNS-01 issuance, requested renewal, automatic renewal of an expired PEM at startup, native persistence and served fingerprint, recreation, CA-outage retention |
| podman-check | Same container smoke checks under rootless Podman with workspace-local storage/runtime |

`scripts-check.sh --regenerate-cron` additionally rebuilds `scripts/cron/init_cron` using the actual entrypoint/source fragments with fixture-only crontab/process shims.

## Isolation

Fixture state/logs stay in ignored `tests/ssl/.work/`, downloads in `tests/ssl/.upstream/`, and short Podman runtime paths in `.ssl-test/`. Keys are synthetic. Docker uses its own storage and requires approval for that host-side use. Unique test containers/networks are removed on exit; images, downloads and fixture evidence remain.

No real `.env`, credentials, production volume or published host port is used. Smoke tests disable networking; ACME containers share an internal-only network. Wizard/wrapper tests extract the relevant functions/blocks without running setup side effects.

Pebble uses a test provider instead of MyAddr. Its DNS server lacks the SOA/NS behavior required by the official propagation probe, so **only the fixture** sets `DPAPI_ACME_PROPAGTIMEOUT_SEC=-1`. The CA still validates the TXT record. Production keeps the official propagation behavior; no new operator setting was added.

## Results And Limits

2026-09-15/16: all five commands passed. Local CA tests observed persisted PEM mode 0644, account-key mode 0600 and parent mode 0700, and compared the served and persisted certificates.

Also passed: `bash -n` on touched Bash scripts/tests, `sh -n` on the three new POSIX helpers, `git diff --check`, and `docker compose --env-file .env.example.<network> config --quiet` for mainnet/preprod/preview. Resolved preprod Compose configuration excluding the intentionally changed `haproxy` and `cron` services compared identical to `HEAD` using sorted JSON. No real `.env` was used.

Not verified: authenticated MyAddr, public/staging CA issuance, authoritative propagation, elapsed-time scheduled renewal, every production backend/API, or production upgrade. Those require separately authorized provider testing and a deployment window. Config parsing alone does not prove production compatibility.

After renaming the setting to `ACME_ENABLED` and the CLI flag to `--ssl-renew`, reran unit/script checks, Docker smoke checks, the full local ACME check, shell syntax and all three example Compose validations successfully. A synthetic Compose assertion confirmed the new environment mappings and absence of Certbot-prefixed mappings. Rootless Podman was not rerun for this name-only change. Local `.env` names/comments were updated without printing values; container tests still use synthetic inputs only.

After adding `TLS_ENABLED` as the Compose-first protocol selector, reran unit and
script fixtures, Docker and rootless Podman smoke checks, the full local ACME
check, shell syntax, actual `.env` Compose validation and all three example
Compose validations successfully. Docker/Podman tests covered plaintext with no
PEM, manual TLS with a PEM, explicit failure for manual TLS without a PEM, and
ACME parsing/issuance without a pre-existing PEM.

After adding HAProxy startup DNS tolerance and `chroot auto`, reran script
fixtures, Docker and rootless Podman smoke checks, the full local ACME check,
unit checks, shell syntax, actual `.env` Compose validation and all three example
Compose validations successfully. Docker/Podman smoke checks include config
parsing with backend names unavailable, proving unresolved backends no longer
fail startup. The local ACME check confirmed issuance, renewal, persistence and
recreation still work with `chroot auto`.
