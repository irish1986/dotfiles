# 0005. herdr replaces tmux

Status: accepted, 2026-09-24

## Context

Work is increasingly done with AI agents in terminal panes. herdr is a terminal multiplexer built for that: agent-aware panes and native session restore after a server restart.

## Decision

herdr is the only multiplexer. The `tmux` role is deleted, and tmux, its config and TPM are on the removal list so existing machines are cleaned up. A login shell execs into herdr from `~/.zshenv`; `HERDR_AUTOSTART=0 zsh -l` is the escape hatch.

herdr is pinned: agent session restore depends on the herdr version, so it must not change under an open session.

## Consequences

- tmux can still be installed by hand when needed; it is not managed.
