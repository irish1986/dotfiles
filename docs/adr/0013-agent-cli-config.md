# 0013. Agent CLI configuration

Status: accepted, 2026-09-26. Supersedes the Claude Code bullet of [0006](0006-scope.md).

## Context

Claude Code and Copilot CLI are both used on the workstation, with the same skills. Skills that interview the user (grilling) prescribe a markdown format for their questions, so the interactive question picker (`AskUserQuestion`, `ask_user`) appeared only when the model happened to choose it. The fix is a global instruction, and a fresh machine had neither that instruction, Copilot CLI, nor the skills in Copilot, because ADR 0006 left `~/.claude` to be managed by hand.

## Decision

The `tools` role owns three things for each agent CLI, and nothing else in `~/.claude` or `~/.copilot`:

- **The CLI**: a `tools_scripts` entry running the vendor's native installer. Not pinned; the CLI updates itself (ADR 0004).
- **The global instructions**: one source file, `roles/tools/files/agents/instructions.md`, copied whole to `~/.claude/CLAUDE.md` and `~/.copilot/copilot-instructions.md` through `tools_files`. A personal global instruction is added there, not on the machine.
- **Plugins**: `tools_agent_plugins` entries, installed with the CLI's own `plugin install` when its `plugin list` does not show them, the marketplace added first. The CLI owns updates. Copilot installs from a marketplace, since direct repository installs are deprecated.

`settings.json`, hooks, credentials and session state stay out: the CLIs rewrite them (ADR 0001), and a plugin install records itself in `settings.json` through the CLI.

## Consequences

- A fresh machine gets both CLIs with the same skills and the same instructions, including in CI, since plugin installs need no login.
- A hand edit to either global instruction file is overwritten on the next run.
- Removing a `tools_agent_plugins` entry stops managing the plugin; uninstalling it is manual.
