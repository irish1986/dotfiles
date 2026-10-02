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

The first run clones the repo to `~/.dotfiles`, creates `~/.config/dotfiles/local.yml` and `~/.dotfiles/.env`, and stops. Fill in your git identity there (and, at work, the package mirrors in `~/.dotfiles/.env`), then run it again:

```bash
~/.dotfiles/scripts/setup
```

Later runs take any `ansible-playbook` option:

```bash
~/.dotfiles/scripts/setup --tags zsh,git      # only those roles
~/.dotfiles/scripts/setup --check --diff      # preview, change nothing
~/.dotfiles/scripts/setup --profile personal  # switch profile
```

To let the playbook add the SSH key to GitHub, put a token in the env file (see [Tokens and secrets](#tokens-and-secrets)), then run `--tags ssh`. gh reads it in place of a login:

```bash
GH_TOKEN=<token>  # fine-grained: Git SSH keys and SSH signing keys, read and write
```

`gh auth login -s admin:public_key,admin:ssh_signing_key` works too, if you would rather keep a stored login.

## Layout

```text
main.yml            the playbook: loads the layers, then runs the roles in order
profiles/           base.yml for every machine, plus personal.yml or work.yml
roles/              certificates, system, zsh, tools, ssh, git, herdr
scripts/setup       the bootstrap
local.example.yml   the local file template
.env.sample         the env file template: tokens and corporate URLs
specs/adr/          why it is shaped this way
specs/CONTEXT.md    the vocabulary
```

Each role is `tasks/main.yml`, `tasks/verify.yml` and the files it uses; `defaults/main.yml` lists what can be changed.

## Configuration

What a machine gets is layered ([ADR 0002](specs/adr/0002-layered-profiles-as-data.md)); a later layer overrides values and appends to lists:

1. [`profiles/base.yml`](profiles/base.yml): every machine.
2. [`profiles/personal.yml`](profiles/personal.yml) or [`profiles/work.yml`](profiles/work.yml): what that kind of machine adds.
3. `~/.config/dotfiles/local.yml`: the local file. Your identity, the profile name, and anything that must not be public. Never committed; see [`local.example.yml`](local.example.yml).

### Work machine

The work network inspects TLS with Zscaler and blocks some public registries ([ADR 0007](specs/adr/0007-work-network.md)):

- `zscaler.cer` is trusted before anything downloads, by `scripts/setup` and then by the `certificates` role. A run fails while it is missing. If your Windows user name differs from the Linux one, set `dotfiles_windows_user` in the local file.
- The package mirrors go in the env file, `~/.dotfiles/.env` ([`.env.sample`](.env.sample) lists them). `scripts/setup` exports it before installing ansible-core, and every shell exports it, so uv and npm use the mirrors without further configuration.

### Tokens and secrets

Tokens and corporate URLs live in one place, the env file `~/.dotfiles/.env` ([ADR 0010](specs/adr/0010-env-file.md)). It is gitignored, mode 0600, created from [`.env.sample`](.env.sample) on the first run, and exported by every shell and by `scripts/setup`. Uncomment what the machine needs and open a new shell.

gh, Copilot CLI, ggshield and snyk log in from it, each reading its own variable; nothing runs a login (grype, syft, hadolint and zizmor need no token):

```bash
GH_TOKEN=<token>             # gh and Copilot CLI, fine-grained (github_pat_): see .env.sample for its permissions
GITGUARDIAN_API_KEY=<token>  # ggshield
SNYK_TOKEN=<token>           # snyk
```

Every run checks these logins and prints one warning naming each tool whose token is unset, a placeholder, or rejected. After editing the env file, open a new shell and check them alone with `~/.dotfiles/scripts/setup --tags auth`.

### Adding a tool

Add an entry to a profile ([ADR 0004](specs/adr/0004-tools-as-lists.md)): `profiles/base.yml` for every machine, `personal.yml` or `work.yml` for one kind. [`roles/tools/defaults/main.yml`](roles/tools/defaults/main.yml) documents each kind. Then run `~/.dotfiles/scripts/setup --tags tools`. Removing an entry stops managing the tool; uninstall it by hand.

## Local development

```bash
prek run --all-files               # every lint hook
ansible-playbook main.yml --check  # preview, change nothing
```

CI converges each profile twice in an `ubuntu:26.04` container; the second run must change nothing ([ADR 0009](specs/adr/0009-ci-converges-twice.md)).

## Contributing

Commit conventions are in [CONTRIBUTING.md](.github/CONTRIBUTING.md). There are no releases: `main` is the version.

## Credits

Heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles) and [TechDufus](https://github.com/TechDufus/dotfiles).

## Licence

MIT — see [LICENSE](.github/LICENSE).
