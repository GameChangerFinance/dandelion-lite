# Contributing to Dandelion Lite

Thank you for helping independent Cardano node operators run reliable, reusable infrastructure. Small, focused improvements and fixes are particularly welcome.

Full medium-big sized contributions, specially AI-assisted, are not welcome without prior governance discussions. 

Time matters for all.

## Before starting

- **Small fixes** (typos, narrow bug fixes, documentation corrections): open a focused pull request directly. If uncertain, open an issue first.
- **Disruptive changes** (architecture, container topology/images, default services, database schemas, networking, public APIs, environment variables, volume names, backup/restore formats, dependency installation, release or upgrade behavior): **discuss the proposal before implementation** in a GitHub issue or the [GameChanger Finance Discord](https://discord.gg/vpbfyRaDKG). Join a Tuesday Dandelion Governance Call when possible (see [GOVERNANCE.md](GOVERNANCE.md)). Agreement to explore a proposal is not a promise to merge it.
- For feature proposals, describe the operator problem, alternatives, compatibility impact, upgrade/migration approach and rollback. A short design outline is enough; please avoid large speculative PRs.
- Please avoid large speculative PRs, specially without previous consultation in governance sessions

## Production-first principles

Dandelion Lite runs real production services. Changes should respect operator uptime, existing automation, deployed data and finite upgrade windows. Prefer backward-compatible, opt-in and reversible improvements over breaking changes or frequent compulsory upgrades. Batch non-urgent upgrades when sensible. Security fixes and network-critical compatibility updates may warrant expedited releases.

Keep changes small and reviewable. Preserve established script names, command arguments, environment keys, storage/backup conventions, API contracts and service manifests unless a breaking change has been agreed upon. Do not silently restart services, recreate volumes, destroy data, expose secrets or install new host packages. Document any necessary operational disruption, prerequisites and a practical rollback plan.

Read [AGENTS.md](AGENTS.md) for the repository's detailed coding and operational invariants; [docs/README.md](docs/README.md) links to authoritative operator documentation.

## Pull requests

1. Fork and branch from the latest `main`; make one coherent change per PR.
2. Explain **why**, summarize **what**, and link the issue or prior discussion when relevant.
3. Document affected services/networks, configuration changes, restart/downtime risk, migration and rollback; write **none** where genuinely inapplicable.
4. Run only relevant, safe checks; note what you ran and what you could not test. For shell changes, at minimum use `bash -n` on modified scripts. Prefer disposable test fixtures; **never run destructive tests on production volumes**.
5. Update affected documentation, and add a short entry to `CHANGELOG.md` under **Unreleased** for operator-visible changes.
6. Submit the PR and allow for asynchronous review. Avoid repeated pings; lack of immediate review does not signal rejection.

No rigid commit-message convention or heavyweight template is required. A PR may be declined or deferred for compatibility, operational risk, scope, maintainability or release-timing reasons, even if technically sound. Maintainers may request splitting a large PR.

## Issues and support

Search existing issues and docs before filing. Include relevant network, software versions, reproduction steps, expected/actual behavior and **redacted** diagnostics. Do not post credentials, private keys, `.env` contents, public-facing database passwords or identifying backup URLs. Use [SECURITY.md](SECURITY.md) for vulnerabilities, not public issues.

This is community-maintained infrastructure, not a guaranteed on-call support service. Please be considerate of operators and contributors across different time zones and capacities.

## Licensing

By contributing, you agree that your contributions are provided under the repository's [MIT license](LICENSE), and confirm you have the right to submit them. Third-party content must preserve its required notices and compatible licensing.
