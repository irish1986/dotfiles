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

On the first run it asks which profile the machine gets (`home` or `work`), the git name and email (offering the ones in `~/.gitconfig`), and the GitHub login. It writes them to the local file and converges without stopping again. That takes a bare Ubuntu install to a working workstation, and is safe to run again afterwards: it asks again only if one of those values is missing, or when you pass `--configure`. Without a terminal it asks nothing, so pass `-- --profile work --yes` and have the local file in place first. Note the form — `bash -c "$(curl ...)"` passes the script as an argument, so stdin stays on the terminal and `sudo` and the questions can prompt; `curl | bash` would consume stdin and the prompt would hang.

Re-runs take arguments:

```bash
~/.dotfiles/scripts/setup --tags zsh,git      # only those roles
~/.dotfiles/scripts/setup --tags configure    # only config, no installs
~/.dotfiles/scripts/setup --check --diff      # preview, change nothing
~/.dotfiles/scripts/setup --configure         # change the profile, git identity or GitHub login
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

A later layer overrides scalars and appends to lists. On the first run `scripts/setup` seeds the local file from [`docs/examples/local.yml`](docs/examples/local.yml) and asks for the profile, git identity and GitHub login. `--profile <name>` switches the profile on later runs. Everything else in the local file is edited by hand.

### Behind a corporate proxy

`profiles/work.yml` enables the `network` role, which takes `network_proxy` and `network_ca_certificates` from the local file and applies them to the shell, apt, docker, git and the playbook run itself (see [`docs/examples/local.yml`](docs/examples/local.yml)). The bootstrap itself runs before any of that, so on the very first run export the proxy, and trust the CA if the proxy intercepts TLS:

```bash
export https_proxy=http://proxy.example.com:8080 http_proxy=http://proxy.example.com:8080
sudo cp /mnt/c/Users/<you>/corp-root-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates
```

### Secrets

The `secrets` role writes secrets into every shell and into project `.env` files ([ADR 0012](docs/adr/0012-secrets.md)). Each machine names one **source** and a list of **targets** in its local file; the repository never holds a value or a secret name.

- **Source**: `infisical` at home (Infisical Cloud, through a machine identity), or `local` where Infisical is out of reach (hand-written files in `~/.config/dotfiles/secrets/`).
- **Targets**: `shell` (a cache in RAM that every new zsh loads, fetched once per boot), or a project `.env` file (rewritten on every sync; git must ignore it).

#### Home machine (Infisical)

1. **In the Infisical dashboard** (<https://app.infisical.com>), once:
   - Create a project. Copy its **Project ID** from the project settings.
   - Create folders for what you keep there, in whichever environment you use (`dev` by default): for example `/shell` for the variables every shell gets, and `/myapp` for one project.
   - Create a **machine identity** with **Universal Auth** (organization Access Control → Identities), add it to the project with read access, and create a **client secret** for it. Copy the client ID and the client secret; the secret is shown once. One identity per distro: the free tier allows five.
2. **In `~/.config/dotfiles/local.yml`**:

   ```yaml
   secrets_source: infisical
   secrets_infisical_project: <project id>
   secrets_targets:
     - { name: shell, dest: shell, env: dev, path: /shell }
     - { name: myapp, dest: ~/git/<you>/myapp/.env, env: dev, path: /myapp }
   ```

3. **Make sure git ignores each project `.env`** (`echo .env >> .gitignore` in that project). Sync refuses to write one that git would commit.
4. **Run the setup.** It installs the Infisical CLI, asks once for the client ID and secret (stored in `~/.config/infisical/universal-auth`, mode 0600), and syncs every target:

   ```bash
   ~/.dotfiles/scripts/setup --tags tools,secrets
   ```

5. **Open a new shell.** It loads the `shell` target.

#### Machine without Infisical

1. In `~/.config/dotfiles/local.yml`, set `secrets_source: local` and the targets (`env` and `path` are ignored):

   ```yaml
   secrets_source: local
   secrets_targets:
     - { name: shell, dest: shell }
     - { name: myapp, dest: ~/git/<you>/myapp/.env }
   ```

2. Write one dotenv file per target, named after it:

   ```bash
   mkdir -p -m 0700 ~/.config/dotfiles/secrets
   install -m 0600 /dev/null ~/.config/dotfiles/secrets/shell.env
   $EDITOR ~/.config/dotfiles/secrets/shell.env   # KEY=value lines; likewise myapp.env
   ```

3. Run `~/.dotfiles/scripts/setup --tags secrets`, then open a new shell.

#### Moving a `.env` into Infisical

Once per file, from a machine with a browser, logged in as yourself rather than as the machine identity:

```bash
infisical login                                   # opens the browser
infisical secrets folders create --name myapp --path / --env dev --projectId <project id>   # if the folder does not exist yet
infisical secrets set --file ~/git/<you>/myapp/.env --env dev --path /myapp --projectId <project id>
infisical logout                                  # the session is stored in ~/.infisical; do not leave it there
```

Check the values in the dashboard, add the target to the local file, then run `scripts/setup --tags secrets`. The first sync keeps your hand-made file as `.env.pre-dotfiles`; delete it once the new `.env` works.

#### Day to day

```bash
dotfiles-secrets sync           # after changing a secret: rewrite every target
dotfiles-secrets sync --shell   # only the shell cache; open a new shell to pick it up
```

Edit secrets in the dashboard (or in `~/.config/dotfiles/secrets/` on a local-source machine), never in the written `.env` files: the next sync overwrites them. After adding or removing a target in the local file, run `scripts/setup --tags secrets`.

#### Rotating the machine identity

1. Create a new client secret for the identity in the dashboard.
2. Remove the stored one and let setup ask again:

   ```bash
   rm ~/.config/infisical/universal-auth
   ~/.dotfiles/scripts/setup --tags secrets
   ```

3. Revoke the old client secret in the dashboard. If a machine is lost, revoking its client secret is enough: nothing else on it can reach Infisical.

#### Troubleshooting

- `dotfiles-secrets sync` prints `updated`, `unchanged` or `failed` for each target, with the reason for a failure. A failed target keeps its last good file.
- A shell that starts with `dotfiles-secrets: this shell has no secrets` could not fetch within 3 seconds: run `dotfiles-secrets sync --shell` to see why.
- `no Infisical credentials`: the credential file is missing; run `scripts/setup --tags secrets` from a terminal.
- `is not ignored by git`: add the `.env` to that project's `.gitignore`.
- `.pre-dotfiles already exists`: an earlier backup is in the way; delete or move it once you have checked it.

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
