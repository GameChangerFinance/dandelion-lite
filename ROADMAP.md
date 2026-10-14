# Roadmap and priorities

Dandelion Lite's roadmap is intentionally directional, not a promise of delivery dates. Development is driven by documented operator needs, compatibility and safe maintenance. The [GitHub issue tracker](https://github.com/GameChangerFinance/dandelion-lite/issues) is the source for current proposals and work status; [TODO.md](TODO.md) contains historical working notes that must not be interpreted as verified open defects.

## Near-term priorities

- **First stable release:** publish an annotated `v1.0.0` tag and GitHub Release
- **Operational reliability:** backup/restore integrity, health checks, clear diagnostics, predictable startup and safe recovery of failed components.
- **Compatibility:** maintain Cardano node, db-sync and public API interoperability while minimizing changes required of existing node operators.
- **Security and documentation:** practical reporting, credential hygiene, operator guides, and tested upgrades with clear impact disclosures.
- **Decentralized participation:** manifests and discoverability enabling independently hosted Dandelion Node Operators to serve multiple Cardano applications.
- **Leios/future hard forks**: prepare for breaking changes, and work in tandem with Cardano GraphQL MKII API efforts.

## Longer-term candidates (subject to discussion)

- Modularity: opt-in configuration of additional services and network-specific features.
- More reproducible upstream component upgrades and configuration checks.
- Operator-focused regression testing with isolated fixtures and network compatibility checks.

Substantial architecture changes and anything affecting existing production nodes must be discussed first as described in [GOVERNANCE.md](GOVERNANCE.md). Priorities may be revised after governance conversations and recorded on GitHub.
