# Security policy

Dandelion Lite coordinates containerized Cardano infrastructure, APIs, databases, credentials and backup processes. Treat security reports involving authentication, exposed data, remote execution, secrets, container boundaries or destructive operations as potentially sensitive.

## Supported versions

Before the first tagged stable release, support is assessed against the current maintained `main` branch. After `v1.0.0` is published, the **latest stable release** is the primary target for security fixes; older versions and individual upstream container images are **not automatically guaranteed** continuing backports. Check [GitHub Releases](https://github.com/GameChangerFinance/dandelion-lite/releases) for current releases and advisories.

## Private reporting

**Do not open a public issue, PR or Discord message containing a proof of concept or exploitable details.** Prefer GitHub's [private vulnerability reporting](https://github.com/GameChangerFinance/dandelion-lite/security/advisories/new) **if enabled for this repository**. If GitHub does not offer that submission form, contact the core maintainer [`zxpectre`](https://github.com/zxpectre) privately through [GameChanger Finance Discord](https://discord.gg/vpbfyRaDKG) to establish a secure communication channel; do not send secrets or exploit instructions in a public channel.

Provide a short summary, affected component/versions, impact, reproducible steps (privately), and suggested mitigations if known. Please allow reasonable time to investigate and coordinate any disclosure with the maintainer before publishing details. Response times are best effort, not guaranteed.

## Operational precautions

Keep `.env`, private keys, database credentials, TLS secrets and backup authentication material out of issues and commits. Limit access to node RPCs, databases, admin interfaces and backups; follow [README.md](README.md) and [docs/README.md](docs/README.md). Validate image provenance and upstream security notices. Keep recoverable backups before upgrades and test restores on isolated systems.

For non-security bug reports, use [GitHub Issues](https://github.com/GameChangerFinance/dandelion-lite/issues).
