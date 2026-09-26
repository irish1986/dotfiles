# 0013. Self-hosted Renovate

Status: accepted, 2026-09-26. Amends the Renovate bullets of [0004](0004-pinned-versions-renovate.md).

## Context

Renovate ran as the Mend-hosted app, on Mend's timing. Dependencies were grouped per manager, but majors and minors shared a group and the pinned tools had no group at all, so one weekly run could open a pull request per tool. Nothing on `main` required a status check, so `platformAutomerge` could merge an update before CI had run, despite ADR 0008 naming `CI OK` the required status.

## Decision

- Renovate runs from `.github/workflows/renovate.yml`: daily at 09:00 UTC, on manual dispatch, when a person edits the Renovate Dashboard, and on every push to `main`. The workflow's cron is the schedule; `renovate.json` has none.
- It authenticates as a private GitHub App installed on this repository alone (`RENOVATE_APP_CLIENT_ID` and `RENOVATE_APP_PRIVATE_KEY`). Pull requests opened with `GITHUB_TOKEN` do not trigger workflows, so CI would never report on them. Commits go through the API (`platformCommit`) and are verified.
- An **ecosystem** is a Renovate manager: GitHub Actions, pre-commit hooks, Ansible collections, and pinned tools (the `# renovate:` annotations in profiles and role defaults, zsh plugins included). Each has at most two pull requests open, one for minor, patch and digest updates and one for majors, and ecosystems never share one.
- Minor, patch and digest updates wait three days after release, then merge themselves once `CI OK` passes. Commit pins that follow a branch head have no release date and skip the wait. Majors open straight away and wait for a human.
- The `main` ruleset requires `CI OK`, with branches up to date and no bypass. `renovate-config-validator --strict` runs in pre-commit, so a broken config fails lint.

## Consequences

- A merge leaves the other auto-merge bundles behind `main`; the push-triggered run rebases them, and each merges after its own converge. The bundles land one after another over a few hours, not all at once.
- One bad update holds back its whole bundle. The fix is a `packageRules` entry for that dependency, not splitting the ecosystem.
- Every pull request, a person's included, needs a green `CI OK` to merge.
- The Renovate version floats within the major that the pinned `renovatebot/github-action` release names (44 today); that major moves only when the action is bumped, through the GitHub Actions bundle.
- Without the App's secrets the workflow fails and nothing updates; there is no fallback to Mend.
