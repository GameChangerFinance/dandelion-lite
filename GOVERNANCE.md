# Dandelion Lite governance

Dandelion Lite is community-driven, with open discussion channels and a production-safety bias. The project seeks more independent, self-sovereign Cardano infrastructure operators, not dependency on a single application or provider. See [docs/concept.md](docs/concept.md).

In 2025 around 10 regular participants were involved in the Governance process. Currently situation changed and more responsabilities and decisions are relying on core maintainer, the only active contributor of the project **Adriano Fiorenza** (GameChanger Finance, GitHub [`zxpectre`](https://github.com/zxpectre)).

## Origins and stewardship

The broader **Dandelion** initiative was created by Gimbalabs co-founder and friend **Roberto Morano** and the Dandelion community. **Dandelion Lite** is a lighter-weight, self-hostable and self-sovereignty-oriented deployment approach co-created by **Adriano Fiorenza** (GameChanger Finance, GitHub [`zxpectre`](https://github.com/zxpectre)) and **Maarten Menhere** (M2Tec), building on the Koios Lite lineage and upstream Cardano tooling. We appreciate the original Dandelion, Koios and broader open-source communities whose work makes this distribution possible.

**Core maintainer:** Adriano Fiorenza (`zxpectre`), who coordinates repository integration, compatibility decisions and releases. See [MAINTAINERS.md](MAINTAINERS.md).

## Where discussions happen

- **GitHub issues and pull requests:** durable technical proposals, review, decisions and change history.
- **[GameChanger Finance Discord](https://discord.gg/vpbfyRaDKG):** live community discussion and event coordination.
- **Tuesday Dandelion Governance Calls:** recurring discussions through GameChanger Finance Discord events, alongside the GCScript DSL / GameChanger Wallet Live Coding Sessions. Consult the Discord **Events** listing for the current time, agenda and access details; schedules can change.

Contributors may discuss ideas in chat or calls. Important decisions affecting the repository should then be summarized in the relevant GitHub issue or PR so absent participants can review the reasoning and implications. Participation in a live call is encouraged for substantial proposals but is not mandatory if an equivalent asynchronous discussion occurs.

## How decisions are made

1. Raise a focused issue or discussion stating the need and expected operator benefit.
2. For disruptive changes, discuss tradeoffs **before extensive implementation**, preferably at a Tuesday call or in Discord/GitHub conversation.
3. Seek practical feedback from affected node operators and contributors, including migration, support and release impact.
4. The core maintainer makes the final merge and release decision after considering technical evidence, risks and community input; consensus is sought but not required. A decision can be deferred when evidence or operator readiness is insufficient.
5. Record significant decisions and reasons in GitHub.

Security vulnerabilities should be reported privately according to [SECURITY.md](SECURITY.md), not debated in public first.

## Release and change policy

Production deployments are not disposable test environments. Prefer stable interfaces, optional migrations, predictable upgrade paths and releases that deliver meaningful improvements without demanding constant sysadmin intervention. Breaking changes require advance discussion, explicit release notes, migration guidance and a workable rollback plan. Urgent security and chain-compatibility corrections may require faster action. See [RELEASING.md](RELEASING.md).

There are no guaranteed meeting quorums, voting thresholds or release dates. Governance can evolve by documented discussion and maintainer approval.

## Conduct

Everyone participating in GitHub, Discord or project calls is expected to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
