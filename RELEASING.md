# Release procedure (maintainer guide)

Dandelion Lite public versions identify **source snapshots of the deployment distribution**, not individual upstream container versions or an automatically deployed production instance. Use annotated Git tags (`v1.0.0`, `v1.0.1`, etc.) and GitHub Releases.

## Release principles

- **Stable operators first:** releases need not follow a fixed weekly cadence. Batch non-urgent changes to reduce repeated operator downtime and maintenance work.
- A release is not proof that every optional or experimental service is supported; scope and limitations must be explicit.
- Compatible fixes typically use PATCH, additive changes MINOR, and disruptive migrations MAJOR. Explain exceptions when upstream Cardano network changes force urgent intervention.
- Tags must never be moved or force-pushed after publication. Issue a new version for corrections.
- Never automatically apply a release to existing production deployments. Operators choose when to upgrade.

## Before a release

1. Review the [README](README.md), [operator guides](docs/README.md), relevant open issues and actual deployment configuration; identify supported services/networks and known limitations. Preserve existing guidance; document any unsupported/disabled components.
2. Review changed scripts, Compose services, images, `.env` behavior and data formats. Document required downtime, backup compatibility, data migration and rollback. Do **not** assert zero downtime without verifying it.
3. Validate safely: `bash -n` for changed shell scripts; applicable tests under `tests/`; `docker compose config` or Podman-equivalent in a disposable, appropriately configured environment. Verify checks actually ran; do not use real production volumes for destructive tests.
4. Ensure operator-facing changes are in `CHANGELOG.md` **[Unreleased]**. Prepare the actual release section `## [X.Y.Z] - YYYY-MM-DD` (real publishing date). Move the relevant entries out of Unreleased; leave a fresh empty `## [Unreleased]` above it. Do not invent an exhaustive history before v1.0.0.
5. Create comparison links: `[Unreleased]: https://github.com/GameChangerFinance/dandelion-lite/compare/vX.Y.Z...HEAD` and `[X.Y.Z]: https://github.com/GameChangerFinance/dandelion-lite/releases/tag/vX.Y.Z`. For subsequent versions, link the new version to the preceding tag with `/compare/vPREVIOUS...vX.Y.Z`.
6. Review and commit documentation/configuration adjustments. Get the release candidate onto the intended branch through normal review practices.

## Manual Git workflow

Run **only after** the release notes and release date are final:

```bash
git fetch origin --tags
git switch main
git pull --ff-only origin main
git status --short                # must be empty
git tag --list 'v1.0.0'         
# Verify HEAD is precisely the validated release commit.
git tag -a v1.0.0 -m 'Dandelion Lite v1.0.0 - initial production release'
git show v1.0.0 --no-patch
git push origin v1.0.0
```

Publish a [GitHub Release](https://github.com/GameChangerFinance/dandelion-lite/releases/new) using **the existing tag**, describing scope, supported configurations, important upstream version considerations, testing evidence, limitations, upgrade and rollback information. No floating-image dependency should be presented as a reproducible pinned dependency.

## After release

Keep an empty `[Unreleased]` section at the top of the changelog and accumulate only notable changes there. Patch releases should target the smallest safe fix; avoid bundling unrelated upgrades into urgent patches. Communicate important operator-facing risks or required action through release notes and community channels.

**Recovery from a mistaken release:** do not rewrite public history or retag; explain the issue and publish a corrected tag (for example `v1.0.1`).
