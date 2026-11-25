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

## Host firewall and external access

Dandelion Lite publishes backend ports on the host by default so local tools and development environments can access individual services. These bindings may listen on all host interfaces; publishing a port does not restrict it to localhost.

We recommend denying unsolicited inbound traffic and exposing or forwarding through a tunnel **only the configured HAProxy ingress port** for public API access. Optionally allow SSH if you need remote administration, preferably restricted to trusted addresses or a VPN. If you use a tunnel for ingress, keep the backend ports inaccessible through the tunnel and the host's external interfaces.

Keep PostgreSQL, direct API ports, NGINX backup serving and administration interfaces private. For development, retain direct access from localhost or explicitly authorized LAN/VPN clients rather than opening these services to the Internet. Use HAProxy with TLS for external access; see [TLS operations](docs/ssl.md).

Apply this policy to the host firewall and any router forwarding or provider firewall, covering both IPv4 and IPv6. Verify access from another machine after deployment and networking changes. With Docker Engine, published ports can bypass UFW's usual filtering path; follow the [container engine's firewall guidance](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw) rather than relying on UFW status alone. Check the effective behavior of your Docker or Podman networking configuration before treating a published port as protected.

## Host kernel protection and nginx2root

Dandelion Lite now defaults to NGINX **1.30.7**, which fixes the NGINX vulnerabilities used by the [nginx2root attack chain](https://nginx.org/en/security_advisories.html). Existing deployments must update their NGINX image to this version or a newer patched release, rebuild and recreate the `nginx` service, and verify the running version with `docker compose exec nginx nginx -v`. Changing configuration files alone does not update a running container.

Containers share the host's Linux kernel. The separate SCTP privilege-escalation vulnerability described in the [original research](https://xint.io/blog/nginx2root-remote-code-execution) therefore requires host protection; updating NGINX blocks the known NGINX entry points but does not patch the kernel.

We recommend keeping the host OS, kernel and container runtime security updates current, rebooting when required, and following your distribution's kernel advisories. If no application on the host needs SCTP, prevent module loading with the following settings in `/etc/modprobe.d/disable-sctp.conf`:

```conf
blacklist sctp
install sctp /bin/false
```

Check SCTP requirements before applying this mitigation. These settings do not unload an already loaded module or disable SCTP built into the kernel; follow your distribution's instructions for those cases. Host hardening remains the operator's responsibility and protects against escalation following a compromise of other services as well.
