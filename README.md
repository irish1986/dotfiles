# dotfiles

<p align="center">
    <a href="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml"><img align="center" src="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
    <a href="https://github.com/irish1986/dotfiles/actions/workflows/docs.yml"><img align="center" src="https://github.com/irish1986/dotfiles/actions/workflows/docs.yml/badge.svg" alt="docs"></a>
    <a href="https://github.com/irish1986/dotfiles/releases/latest"><img align="center" src="https://img.shields.io/github/v/release/irish1986/dotfiles" alt="release"></a>
    <a href="https://github.com/irish1986/dotfiles/issues"><img align="center" src="https://img.shields.io/github/issues/irish1986/dotfiles" alt="issues"></a>
    <a href="https://github.com/irish1986/dotfiles/blob/main/.github/LICENSE"><img align="center" src="https://img.shields.io/github/license/irish1986/dotfiles" alt="licence"></a>
</p>

Ansible playbook that provisions a Windows 11 + WSL2 Ubuntu workstation, and the shell, editor and tooling configuration that goes with it.

**Documentation: <https://irish1986.github.io/dotfiles/>**

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
- **Every supported Ubuntu LTS** — 22.04, 24.04 and 26.04, with no codename hardcoded anywhere.
- **WSL2 first.** The Windows side is managed too: Terminal settings, fonts, clipboard, `wsl.conf` and `.wslconfig`.
- **Fail loudly.** Each role ends by asserting the thing it installs actually works, so a role cannot quietly do nothing.

## Documentation

| Section | Contents |
| --- | --- |
| [Getting started](https://irish1986.github.io/dotfiles/getting-started/) | Install, configure, secrets |
| [Roles](https://irish1986.github.io/dotfiles/roles/) | What each role does, generated from its source |
| [Reference](https://irish1986.github.io/dotfiles/reference/) | Variables, collections, CLI, playbook |
| [Architecture](https://irish1986.github.io/dotfiles/architecture/) | Role layout and the WSL boundary |
| [Troubleshooting](https://irish1986.github.io/dotfiles/about/troubleshooting/) | Things that go wrong |

Role pages, the variables table and the collections table are generated from the repository on every docs build, so they cannot drift from the code.

## Configuration

Machine configuration lives in `inventory/group_vars/all.yml`, which is gitignored because it holds identity. `scripts/setup` seeds it from [`docs/examples/group_vars-all.yml`](docs/examples/group_vars-all.yml) on a fresh clone, filling in your user, home directory and hostname. To reset it:

```bash
cp ~/.dotfiles/docs/examples/group_vars-all.yml ~/.dotfiles/inventory/group_vars/all.yml
```

`dotfiles_roles` in that file decides which roles run.

## Local development

```bash
uv run mkdocs serve                # docs at http://127.0.0.1:8000
prek run --all-files               # every lint hook
scripts/check-structure            # role layout checks
ansible-playbook main.yml --check  # preview, change nothing
```

## Contributing

Commit conventions and the release process are in [CONTRIBUTING.md](.github/CONTRIBUTING.md). Releases are automated by release-please; there is nothing to run by hand.

## Credits

Heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles) and [TechDufus](https://github.com/TechDufus/dotfiles).

## Licence

MIT — see [LICENSE](.github/LICENSE).
