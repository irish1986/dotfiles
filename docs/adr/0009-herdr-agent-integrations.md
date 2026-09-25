# 0009. herdr installs its agent hooks

Status: accepted, 2026-09-25. Narrows [0006](0006-scope.md).

## Context

ADR 0006 leaves `~/.claude` to be managed by hand. herdr's `[session] resume_agents_on_restore = true` resumes each agent pane into its native conversation after a server restart, but only for agents whose herdr integration is installed: the integration's hook reports the session reference that restore resumes from. None was installed, so the setting did nothing, and the hooks that had been installed by hand were several versions behind herdr's.

Integration versions are tied to herdr's, so keeping them current by hand means remembering to reinstall after every herdr bump.

## Decision

The herdr role runs `herdr integration install <agent>` for Claude Code and GitHub Copilot CLI, whenever `herdr integration status` does not report that integration as current. It does so only when the agent's own directory (`~/.claude`, `~/.copilot`) exists: herdr refuses otherwise, and installing an agent is not this role's job.

That command writes exactly two things per agent, and they are the whole carve-out:

- herdr's hook script, `hooks/herdr-agent-state.sh`
- herdr's hook entries in that agent's `settings.json`, merged in without touching anything else

Everything else under `~/.claude` and `~/.copilot` stays yours, explicitly including Claude's `statusLine`: the usage display documents its statusLine bridge as a manual step rather than managing it.

## Consequences

- Agent panes resume after a server restart, and a herdr bump brings its hooks along on the next run.
- The role edits a file it does not own. That is acceptable because herdr performs the merge and leaves unrelated keys byte-for-byte unchanged; the role never templates or rewrites `settings.json` itself.
