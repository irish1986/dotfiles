# 0004. Pinned versions, bumped by Renovate

Status: accepted, 2026-09-24

## Context

Several roles resolved "latest" from the GitHub API on every run: reruns changed things with no commit, and CI hit the unauthenticated rate limit. The repo also carried release-please, a changelog, a version file and both Dependabot and Renovate.

## Decision

- Every tool installed from a release (binaries, `.deb`s, installer scripts, uv tools) is pinned. A `# renovate:` comment above each `version:` lets Renovate open a pull request per bump, and CI converges it before merge.
- apt packages follow the archive and are upgraded by the `update` role. Claude Code keeps its own updater, because its native installer is built around it.
- Renovate is the only dependency bot. It also covers GitHub Actions, pre-commit hooks and Galaxy collections.
- No releases: `main` is the version. Conventional Commits stay.

## Consequences

- A rerun is reproducible; a version change is always a reviewed commit.
- Renovate PRs are the maintenance load. Minor and patch updates automerge once CI is green.
