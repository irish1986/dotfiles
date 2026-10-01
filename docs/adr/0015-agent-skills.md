# 0015. Agent skills via the skills CLI

Status: accepted, 2026-10-01. Supersedes the Plugins bullet of [0014](0014-agent-cli-config.md).

## Context

ADR 0014 gave Claude Code and Copilot CLI the same skills through each CLI's plugin system. That covers a skill set only when its repository publishes a plugin marketplace for both CLIs. Most skills do not: herdr's and gh-stack's are a `SKILL.md` folder in a repository, installed by hand with the skills CLI (`npx skills add`), so a fresh machine lacked them and the two CLIs drifted.

The skills CLI installs one copy of a skill under `~/.agents/skills` and links it into each agent's own directory. Copilot CLI reads `~/.agents/skills` directly; Claude Code reads `~/.claude/skills`, where the CLI puts a symlink.

## Decision

Global agent skills are `tools_agent_skills` entries, installed by the `tools` role with `npx skills@<version> add <source> --skill <names> --global --agent <agents> --yes`:

- **Entries** name a source (a GitHub owner/repo) and its skills, `'*'` for all of them. They are installed for every agent in `tools_agent_skill_agents`: `github-copilot` in `base.yml`, `claude-code` added by `home.yml`, since Claude Code is a home-only CLI.
- **Installed once.** A run installs an entry when a skill's `SKILL.md` is missing from an agent's directory; for `'*'`, the skills CLI's lock file says which skills the source gave. `npx skills update -g` is yours to run, as the CLIs and their plugins update themselves (ADR 0004). The verify phase asserts every skill is in place.
- **The skills CLI is pinned**, `tools_agent_skills_cli_version`, and Renovate bumps it from npm. It runs on the nvm node (`tools_nvm_node_version`), which every profile that has skills needs.
- **Plugins are only for what a skill cannot do**, such as hooks or MCP servers. A skill set that is only skills moves to an entry here, and its plugin is uninstalled.

## Consequences

- Adding a skill everywhere is one entry in `base.yml`.
- Each run reads the skill files and the lock file, never the network, so a second run stays `changed=0`.
- Removing an entry stops managing the skill; `npx skills remove -g <name>` uninstalls it.
- A skill edited by hand in `~/.agents/skills` is kept: only a missing skill triggers an install.
