# Getting started

## Bootstrap

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)"
```

Note the form. `bash -c "$(curl ...)"` passes the script as an argument, so stdin
stays attached to your terminal and `sudo` can prompt. `curl | bash` would
consume stdin and the prompt would hang on a blank screen.

The script:

1. Checks the OS is a supported Ubuntu LTS, and refuses otherwise.
2. Installs `curl`, `git`, `python3` and `ca-certificates` if missing.
3. Installs [uv](https://docs.astral.sh/uv/), then `ansible-core` and the pinned
   Galaxy collections into an isolated environment.
4. Clones this repository to `~/.dotfiles`.
5. Seeds `inventory/group_vars/all.yml` from the example, filling in your user,
   home directory and hostname.
6. Runs the playbook.

Everything after step 4 is idempotent, so re-running is cheap and safe.

## Re-running

```bash
~/.dotfiles/scripts/setup                     # everything in dotfiles_roles
~/.dotfiles/scripts/setup --tags zsh,git      # only those roles
~/.dotfiles/scripts/setup --tags configure    # only config, no installs
~/.dotfiles/scripts/setup --check --diff      # preview, change nothing
~/.dotfiles/scripts/setup --skip-tags update  # skip the apt upgrade
~/.dotfiles/scripts/setup --help
```

`--tags configure` is the one worth remembering: it re-deploys dotfiles and
configuration without touching any package manager.

Run logs are kept in `~/.local/state/dotfiles/`, ten at a time, and are not
deleted when a run fails.

## First-run notes

- **Two sudo prompts.** One for the script's own package installs, one for
  Ansible. After the first successful run the `system` role grants passwordless
  sudo and both stop.
- **Log out and back in** to pick up the `docker` group.
- **On WSL**, run `wsl --shutdown` from Windows if `wsl.conf` or `.wslconfig`
  changed. Ansible reports when they did.

## Next

- [Prerequisites](prerequisites.md) if you are starting from nothing.
- [Configuration](configuration.md) to choose which roles run.
- [Secrets](secrets.md) if you want the Bitwarden-backed environment.
