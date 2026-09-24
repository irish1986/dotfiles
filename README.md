# dotfiles

<p align="center">
    <a href="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml"><img align="center" src="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
    <a href="https://github.com/irish1986/dotfiles/issues"><img align="center" src="https://img.shields.io/github/issues/irish1986/dotfiles" alt="issues"></a>
    <a href="https://github.com/irish1986/dotfiles/blob/main/.github/LICENSE"><img align="center" src="https://img.shields.io/github/license/irish1986/dotfiles" alt="licence"></a>
</p>

Ansible playbook that provisions a Windows 11 + WSL2 Ubuntu workstation, and the shell, editor and tooling configuration that goes with it.

## Quick start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)"
```

That takes a bare Ubuntu install to a working workstation, and is safe to run again afterwards. Note the form — `bash -c "$(curl ...)"` passes the script as an argument, so stdin stays on the terminal and `sudo` can prompt; `curl | bash` would consume stdin and the prompt would hang.

Re-runs take arguments:

```bash
~/.dotfiles/scripts/setup --tags zsh,git      # only those roles
~/.dotfiles/scripts/setup --tags configure    # only config, no installs
~/.dotfiles/scripts/setup --check --diff      # preview, change nothing
~/.dotfiles/scripts/setup --help
```

## Goals

- **One command on a fresh machine**, and safe to re-run.
- **Ubuntu 24.04 and 26.04** ([ADR 0007](docs/adr/0007-ubuntu-support.md)), with no codename hardcoded anywhere.
- **WSL2 first.** The Windows side is managed too: Terminal settings, fonts, clipboard, `wsl.conf` and `.wslconfig`.
- **Fail loudly.** Each role ends by asserting the thing it installs actually works, so a role cannot quietly do nothing.

## Documentation

- [`CONTEXT.md`](CONTEXT.md) — what the repo is and the vocabulary it uses.
- [`docs/adr/`](docs/adr/) — why it is shaped the way it is.
- `roles/` — the reference: each role's `defaults/main.yml` lists what can be changed.

## Configuration

Machine configuration lives in `inventory/group_vars/all.yml`, which is gitignored because it holds identity. `scripts/setup` seeds it from [`docs/examples/group_vars-all.yml`](docs/examples/group_vars-all.yml) on a fresh clone, filling in your user, home directory and hostname. To reset it:

```bash
cp ~/.dotfiles/docs/examples/group_vars-all.yml ~/.dotfiles/inventory/group_vars/all.yml
```

`dotfiles_roles` in that file decides which roles run.

## Local development

```bash
prek run --all-files               # every lint hook
scripts/check-structure            # role layout checks
ansible-playbook main.yml --check  # preview, change nothing
```

## Contributing

Commit conventions are in [CONTRIBUTING.md](.github/CONTRIBUTING.md). There are no releases: `main` is the version.

## Credits

Heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles) and [TechDufus](https://github.com/TechDufus/dotfiles).

## Licence

MIT — see [LICENSE](.github/LICENSE).
