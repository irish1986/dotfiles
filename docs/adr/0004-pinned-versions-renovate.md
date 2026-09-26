# 0004. Pinned versions, bumped by Renovate

Status: accepted, 2026-09-24

## Context

Several roles resolved "latest" from the GitHub API on every run: reruns changed things with no commit, and CI hit the unauthenticated rate limit. The repo also carried release-please, a changelog, a version file and both Dependabot and Renovate.

## Decision

- Every tool installed from a release (binaries, `.deb`s, uv tools, Nerd Fonts, herdr, win32yank) is pinned. A `# renovate:` comment above each `version:` lets Renovate open a pull request per bump, and CI converges it before merge.
- apt packages follow the archive and are upgraded by the `update` role.
- Installer scripts (uv, rustup, Claude Code, GitHub Copilot CLI) run once and the tool's own updater owns upgrades afterwards; a script that takes a version (nvm) is pinned for that first install.
- Renovate is the only dependency bot. It also covers GitHub Actions, pre-commit hooks and Galaxy collections.
- No releases: `main` is the version. Conventional Commits stay.

## Consequences

- A rerun is reproducible; a version change is always a reviewed commit.
- Renovate PRs are the maintenance load. Minor and patch updates automerge once CI is green.
