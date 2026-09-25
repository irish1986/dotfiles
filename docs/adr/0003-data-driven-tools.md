# 0003. Data-driven tools

Status: accepted, 2026-09-24

## Context

Every tool was a full role of six to eight files, including tools that are a single `apt install`. Adding a tool meant copying a role, and most of the repo's size was that boilerplate.

## Decision

A single `tools` role installs tool entries from lists in the profiles: apt packages, apt repositories, `.deb` releases, release binaries, installer scripts and uv tools, plus config files for them. Each entry that is not a plain apt package carries a `verify` command, defaulting to `<name> --version`.

Full roles remain only for things with real configuration: zsh, git, ssh, herdr, wsl and network, plus the system-level roles.

Uninstalling is explicit: `tools_remove_apt` and `tools_remove_paths`. Deleting an entry only stops managing it.

## Consequences

- Adding a tool is one entry in a profile.
- Tags work per role, not per tool: `--tags tools` runs every tool entry.
- A tool that grows real configuration graduates to a full role.

## Amendment, 2026-09-25

- Docker is a `tools_apt_repos` entry in `profiles/base.yml`. Its daemon configuration (`daemon.json`, the service) is the one tool-specific task file in the `tools` role, `tasks/docker.yml`, applied when an entry named `docker` is present. The full `docker` role is gone.
- Apt repositories are configured only by the `tools` role (`tasks/kinds/apt_repo.yml`). The `apt_repo` helper role is gone.
- The Nerd Fonts moved from their own `fonts` role into `system`. The `wsl` role still registers them with Windows.
