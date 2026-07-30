# Command line

`scripts/setup` bootstraps a fresh machine and re-applies the playbook. It is
safe to run repeatedly.

```bash
scripts/setup [options] [-- ansible-playbook args]
```

## Options

| Option | Effect |
| --- | --- |
| `-t`, `--tags TAGS` | Only run roles or phases matching `TAGS` |
| `--skip-tags TAGS` | Skip roles or phases matching `TAGS` |
| `-c`, `--check` | Ansible check mode; make no changes |
| `-d`, `--diff` | Show file differences |
| `--syntax-check` | Parse the playbook and exit |
| `--list-tags` | List available tags and exit |
| `-n`, `--dry-run` | Script-level no-op; implies `--check` |
| `--branch BRANCH` | Check out `BRANCH` instead of the current one |
| `--no-pull` | Do not fetch or update the repository |
| `--no-reexec` | Do not hand over to the freshly checked-out script |
| `--generate-ssh-key` | Create `~/.ssh/id_ed25519` if absent |
| `--remote-protocol P` | `origin` protocol afterwards: `auto`, `ssh` or `https` |
| `-y`, `--yes` | Assume yes for all prompts |
| `-v`, `--verbose` | Increase Ansible verbosity; repeatable |
| `-h`, `--help` | Show help |
| `--version` | Show the script version |

Anything after `--` is passed to `ansible-playbook` unchanged. An unknown option
is an error rather than being forwarded, so a typo cannot become an accidental
`--limit`.

## Environment

| Variable | Effect |
| --- | --- |
| `DOTFILES_DIR` | Checkout location; default `~/.dotfiles` |
| `BWS_ACCESS_TOKEN` | Bitwarden Secrets Manager token |
| `GH_TOKEN` | Lifts the api.github.com rate limit for release lookups |
| `NO_COLOR` | Disable colour output |

## State

| Path | Contents |
| --- | --- |
| `~/.config/dotfiles/setup.env` | Sourced if present; should be mode `0600` |
| `~/.local/state/dotfiles/` | Run logs, last ten kept |
| `~/.local/state/dotfiles/collections.sha256` | Collection install stamp |

Logs are appended to and are **not** deleted when a run fails. On failure the
last 40 lines are printed along with the command that failed.

## Behaviour worth knowing

**Updating never blocks a run.** Fetch, stash if dirty, fast-forward, pop. Every
failure path — a diverged history, a detached HEAD, no upstream, an unreachable
remote — degrades to a warning and the on-disk playbook runs anyway.

**Two sudo prompts on a first run.** Warming the sudo ticket covers the script's
own apt calls but not Ansible: the local connection plugin runs `sudo -H -S -n`
with no controlling tty, and `tty_tickets` keys the timestamp to the terminal, so
the warmed ticket does not satisfy it. `--ask-become-pass` is passed when
passwordless sudo is unavailable. After one run the `system` role grants NOPASSWD
and prompting stops.

**Clone is HTTPS, then switched to SSH.** There is no key on a bare machine, so
the clone must be HTTPS; `origin` is switched to SSH once GitHub actually
authenticates, so the machine can push.
