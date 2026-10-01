# dotfiles

<p align="center">
    <a href="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml"><img align="center" src="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
    <a href="https://github.com/irish1986/dotfiles/issues"><img align="center" src="https://img.shields.io/github/issues/irish1986/dotfiles" alt="issues"></a>
    <a href="https://github.com/irish1986/dotfiles/blob/main/.github/LICENSE"><img align="center" src="https://img.shields.io/github/license/irish1986/dotfiles" alt="licence"></a>
</p>

An Ansible playbook that sets up a WSL2 Ubuntu 26.04 distro: zsh, git, ssh, docker, herdr, agent CLIs and the rest of the tooling, for a personal or a work machine. Safe to run again at any time.

## Quick start

On Windows, once:

1. Create the SSH key, in PowerShell: `ssh-keygen -t ed25519`. The playbook copies it into the distro and adds it to GitHub.
2. Install a [Nerd Font](https://www.nerdfonts.com/font-downloads) (Hack) and pick it in Windows Terminal; the prompt needs its icons.
3. **Work machine only:** export the Zscaler root certificate to `C:\Users\<you>\zscaler.cer`: open `certmgr.msc`, then Trusted Root Certification Authorities, Certificates, right-click the Zscaler root, All Tasks, Export. Either format works.

In the distro:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)" -- --profile work   # or personal
```

The first run clones the repo to `~/.dotfiles`, creates `~/.config/dotfiles/local.yml` and stops. Fill in your git identity there (and, at work, the package mirrors), then run it again:

```bash
~/.dotfiles/scripts/setup
```

Later runs take any `ansible-playbook` option:

```bash
~/.dotfiles/scripts/setup --tags zsh,git      # only those roles
~/.dotfiles/scripts/setup --check --diff      # preview, change nothing
~/.dotfiles/scripts/setup --profile personal  # switch profile
```

Once it has run, log in to GitHub with the key scopes so the playbook can add the SSH key, then run `--tags ssh`:

```bash
gh auth login -s admin:public_key,admin:ssh_signing_key
```

## Layout

```text
main.yml            the playbook: loads the layers, then runs the roles in order
profiles/           base.yml for every machine, plus personal.yml or work.yml
roles/              certificates, system, zsh, tools, ssh, git, herdr
scripts/setup       the bootstrap
docs/examples/      the local file template
docs/adr/           why it is shaped this way
CONTEXT.md          the vocabulary
```

Each role is `tasks/main.yml`, `tasks/verify.yml` and the files it uses; `defaults/main.yml` lists what can be changed.

## Configuration

What a machine gets is layered ([ADR 0002](docs/adr/0002-layered-profiles-as-data.md)); a later layer overrides values and appends to lists:

1. [`profiles/base.yml`](profiles/base.yml): every machine.
2. [`profiles/personal.yml`](profiles/personal.yml) or [`profiles/work.yml`](profiles/work.yml): what that kind of machine adds.
3. `~/.config/dotfiles/local.yml`: the local file. Your identity, the profile name, and anything that must not be public. Never committed; see [`docs/examples/local.yml`](docs/examples/local.yml).

### Work machine

The work network inspects TLS with Zscaler and blocks some public registries ([ADR 0007](docs/adr/0007-work-network.md)):

- `zscaler.cer` is trusted before anything downloads, by `scripts/setup` and then by the `certificates` role. A run fails while it is missing. If your Windows user name differs from the Linux one, set `dotfiles_windows_user` in the local file.
- The package mirrors go in the local file; `scripts/setup` uses them to install ansible-core, and the playbook writes them to uv's and npm's config:

  ```yaml
  tools_pypi_mirror: https://artifactory.example.com/api/pypi/pypi/simple
  tools_python_install_mirror: https://artifactory.example.com/artifactory/github/astral-sh/python-build-standalone/releases/download
  tools_npm_registry: https://artifactory.example.com/api/npm/npm/
  ```

### Adding a tool

Add an entry to a profile ([ADR 0004](docs/adr/0004-tools-as-lists.md)): `profiles/base.yml` for every machine, `personal.yml` or `work.yml` for one kind. [`roles/tools/defaults/main.yml`](roles/tools/defaults/main.yml) documents each kind. Then run `~/.dotfiles/scripts/setup --tags tools`. Removing an entry stops managing the tool; uninstall it by hand.

## Local development

```bash
prek run --all-files               # every lint hook
ansible-playbook main.yml --check  # preview, change nothing
```

CI converges each profile twice in an `ubuntu:26.04` container; the second run must change nothing ([ADR 0009](docs/adr/0009-ci-converges-twice.md)).

## Contributing

Commit conventions are in [CONTRIBUTING.md](.github/CONTRIBUTING.md). There are no releases: `main` is the version.

## Credits

Heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles) and [TechDufus](https://github.com/TechDufus/dotfiles).

## Licence

MIT — see [LICENSE](.github/LICENSE).
