# Agent CLI instructions and skills

Status: accepted, 2026-10-01

The repo owns one set of global instructions for every agent CLI (`roles/tools/files/agents/instructions.md`, copied to `~/.copilot/copilot-instructions.md` and, on a personal machine, `~/.claude/CLAUDE.md`), the agent skills every CLI loads, and the MCP servers each CLI uses. Skills are installed globally with the skills CLI (`skills add`, itself an npm tool entry) for each agent in `tools_agent_skill_agents`. MCP server entries are merged into each configured CLI's user-level config, preserving unrelated settings and servers. Credentials and session history remain user-owned and are never managed by the repo.

Each skill source is pinned to a `version`, a tag or a commit SHA that Renovate bumps. Skills are installed when one is missing from an agent's skills directory or the skills lock records another ref; `skills update -g` refreshes them at the pinned ref. Claude Code is installed on personal machines only.
