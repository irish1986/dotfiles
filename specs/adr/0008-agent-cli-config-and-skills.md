# Agent CLI instructions and skills

Status: accepted, 2026-10-01

The repo owns one set of global instructions for every agent CLI (`roles/tools/files/agents/instructions.md`, copied to `~/.copilot/copilot-instructions.md` and, on a personal machine, `~/.claude/CLAUDE.md`) and the agent skills every CLI loads, installed globally with the skills CLI (`npx skills add`) for each agent in `tools_agent_skill_agents`. It never manages the CLIs' settings, credentials or session history: those change from inside the tools and would be reverted on every run.

Skills are installed when one is missing from an agent's skills directory; `npx skills update -g` updates them. Claude Code is installed on personal machines only.
