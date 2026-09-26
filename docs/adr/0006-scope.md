# 0006. Scope

Status: accepted, 2026-09-24

## Context

Over time the repo also became a template source for other projects (the `github` role's workflows, dependabot and label files, copilot instruction files), a secrets manager (Bitwarden lookups into `~/.zshenv`) and a documentation site generated from the roles.

## Decision

The repo owns one workstation: the Ubuntu side (packages, shell, tools and their config) and the Windows side reachable through WSL interop (`.wslconfig`, Windows Terminal settings, per-user fonts).

Out of scope, and removed:

- Templates for other repositories. They live in their own repositories.
- Secrets management. Environment secrets are managed by hand, outside the repo. Superseded by [0012](0012-secrets.md): the repo wires the delivery of secrets, never their values.
- The MkDocs site. `README.md`, this directory and `CONTEXT.md` are the documentation; the role source is the reference.
- Configuration of Claude Code and GitHub Copilot CLI. The `tools` role installs them; `~/.claude` and `~/.copilot` are managed by hand.

## Consequences

- Plain Ubuntu (a VM, a container) must still converge, with every Windows-side task skipped; that is also how CI runs.
