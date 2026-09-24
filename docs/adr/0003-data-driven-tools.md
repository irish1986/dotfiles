# 0003. Data-driven tools

Status: accepted, 2026-09-24

## Context

Every tool was a full role of six to eight files, including tools that are a single `apt install`. Adding a tool meant copying a role, and most of the repo's size was that boilerplate.

## Decision

A single `tools` role installs tool entries from lists in the profiles: apt packages, apt repositories, `.deb` releases, release binaries, installer scripts and uv tools, plus config files for them. Each entry that is not a plain apt package carries a `verify` command, defaulting to `<name> --version`.

Full roles remain only for things with real configuration: zsh, git, ssh, docker, herdr, wsl and network, plus the system-level roles.

Uninstalling is explicit: `tools_remove_apt` and `tools_remove_paths`. Deleting an entry only stops managing it.

## Consequences

- Adding a tool is one entry in a profile.
- Tags work per role, not per tool: `--tags tools` runs every tool entry.
- A tool that grows real configuration graduates to a full role.
