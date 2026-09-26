# 0012. Secrets from Infisical

Status: accepted, 2026-09-25. Supersedes the secrets bullet of [0006](0006-scope.md).

## Context

ADR 0006 put secrets out of scope after Bitwarden lookups had written values into `~/.zshenv`. What replaced them was hand-kept `.env` files: plaintext, scattered across projects, copied between machines by hand, and never rotated. Infisical is available at home; at work it is not.

## Decision

The repository wires the delivery of secrets; it never holds a secret value or a secret name.

- The `secrets` role is a full role (ADR 0003): it renders config, manages a `~/.zshenv` block and syncs. It installs `dotfiles-secrets`, a script that writes each **secret target** from the machine's **secret source**. The local file names both; the repository only knows their shape.
- The source is set explicitly with `secrets_source`, never guessed:
  - `infisical`: Infisical Cloud (US), reached as a machine identity (universal auth). Its client ID and secret sit in `~/.config/infisical/universal-auth` (0600), entered once through `scripts/setup`.
  - `local`: hand-written dotenv files in `~/.config/dotfiles/secrets/`, for machines without Infisical access.
- A target is the `shell` (a cache in RAM that every zsh sources, fetched by the first interactive shell after a boot) or a project `.env` file (0600; inside a git repository only where git ignores it; a hand-made one is kept once as `.env.pre-dotfiles`, after the replacement is fetched).
- `dotfiles-secrets sync` writes every target. The playbook runs it at the end of the role; you run it after changing a secret. There is no daemon.
- The Infisical CLI is a `tools_apt_repos` entry in `profiles/home.yml`, since the `tools` role owns apt repositories (ADR 0003). Its repository serves one `stable` suite for every release, so it is not probed (ADR 0007).
- The shell cache is at a fixed path, `/dev/shm/dotfiles-secrets-<uid>/shell.env`, rather than under `XDG_RUNTIME_DIR`, which is set in a login shell and not under sudo or the playbook, and would split the cache in two.
- It is read-only. Secrets are edited at the source; moving an existing `.env` into Infisical is a one-off `infisical secrets set --file=.env --env=<env> --path=<folder>`.

## Consequences

- One place to edit a secret per machine kind, and project `.env` files are regenerated, not hand-copied.
- The machine identity's client secret and every project `.env` are plaintext at rest, protected by file mode alone. The shell cache never touches disk.
- A fetch that fails leaves the last good file in place and fails the sync; it never falls back to the other source.
- A shell started while Infisical is unreachable waits up to 3 seconds, then starts without the variables.
- Work secrets stay hand-managed, but in one directory rather than one file per project.
- The free Infisical tier allows five machine identities: one per home distro.
