# dotfiles

<p align="center">
    <a href="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml"><img align="center" src="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
    <a href="https://github.com/irish1986/dotfiles/issues"><img align="center" src="https://img.shields.io/github/issues/irish1986/dotfiles" alt="issues"></a>
    <a href="https://github.com/irish1986/dotfiles/blob/main/.github/LICENSE"><img align="center" src="https://img.shields.io/github/license/irish1986/dotfiles" alt="licence"></a>
</p>

Ansible playbook that provisions a Windows 11 + WSL2 Ubuntu workstation, and the shell, editor and tooling configuration that goes with it.

## Quick start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)" -- --profile home
```

Use `--profile work` on a work machine. That takes a bare Ubuntu install to a working workstation, and is safe to run again afterwards. Note the form — `bash -c "$(curl ...)"` passes the script as an argument, so stdin stays on the terminal and `sudo` can prompt; `curl | bash` would consume stdin and the prompt would hang.

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

What a machine gets is layered ([ADR 0002](docs/adr/0002-profiles-and-local-file.md)):

1. [`profiles/base.yml`](profiles/base.yml) — every machine.
2. [`profiles/home.yml`](profiles/home.yml) or [`profiles/work.yml`](profiles/work.yml) — what that kind of machine adds.
3. `~/.config/dotfiles/local.yml` — the local file: which profile this machine is, git identity, anything machine-specific. Never committed.

A later layer overrides scalars and appends to lists. `scripts/setup --profile <name>` seeds the local file from [`docs/examples/local.yml`](docs/examples/local.yml) on first run, and switches the profile on later ones.

### Behind a corporate proxy

`profiles/work.yml` enables the `network` role, which takes `network_proxy` and `network_ca_certificates` from the local file and applies them to the shell, apt, docker, git and the playbook run itself (see [`docs/examples/local.yml`](docs/examples/local.yml)). The bootstrap itself runs before any of that, so on the very first run export the proxy, and trust the CA if the proxy intercepts TLS:

```bash
export https_proxy=http://proxy.example.com:8080 http_proxy=http://proxy.example.com:8080
sudo cp /mnt/c/Users/<you>/corp-root-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates
```

## Adding a tool

Add a tool entry to a profile ([ADR 0003](docs/adr/0003-data-driven-tools.md)) — `profiles/base.yml` for every machine, `home.yml` or `work.yml` for one kind. [`roles/tools/defaults/main.yml`](roles/tools/defaults/main.yml) documents each kind: apt package, apt repository, `.deb`, release binary, installer script, uv tool, config file. Then:

```bash
~/.dotfiles/scripts/setup --tags tools
```

Removing an entry stops managing the tool; to uninstall it, add it to `tools_remove_apt` or `tools_remove_paths`.

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
