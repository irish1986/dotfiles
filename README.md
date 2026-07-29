# dotfiles

![dotfiles-logo](https://github.com/TechDufus/dotfiles/assets/46715299/6c1d626d-28d2-41e3-bde5-981d9bf93462)

<p align="center">
    <a href="https://github.com/irish1986/dotfiles/actions/workflows/main.yml"><img align="center" src="https://github.com/irish1986/dotfiles/actions/workflows/main.yml/badge.svg" alt="ci pipeline"></a>
    <a href="https://github.com/irish1986/dotfiles/issues"><img align="center" src="https://img.shields.io/github/issues/irish1986/dotfiles" alt="issues"></a>
    <a href="https://github.com/irish1986/dotfiles/pulls"><img align="center" src="https://img.shields.io/github/issues-pr/irish1986/dotfiles" alt="pull requests"></a>
    <a href="https://github.com/irish1986/dotfiles/commits/main"><img align="center" src="https://img.shields.io/github/commit-activity/m/irish1986/dotfiles" alt="commit frequency"></a>
</p>

---

## Goals

Provide idempotent deployment mechanism for my computers from a versioned controlled source targeting `Ubuntu` that is easy to set up and maintain.  I am mostly using this setup with WSL2 on Windows 11 to sync various workstation and laptops; both for personal and professional usage. Signed

## Getting Started

### Setup WSL2

```powershell
wsl --unregister ${existing-distro}
wsl --install -d ${target-distro}
wsl --setdefault ${target-distro}
```

### ssh-key management

You will need to add a valid ssh-key to your GitHub account.

You can either create a WSL2 owned key as following:

```bash
ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C $USER@$HOSTNAME
```

You can also share Windows key with WSL2 owned key as following:

```bash
cp -r /mnt/c/Users/$USER/.ssh/id_ed25519* ~/.ssh
chmod 600 ~/.ssh/id_ed25519*
cat ~/.ssh/id_ed25519.pub | clip.exe
```

Sometimes it is useful to pull your existing public keys from GitHub.

```bash
curl https://github.com/irish1986.keys >> ~/.ssh/authorized_keys
```

### Install

`scripts/setup` bootstraps a fresh Ubuntu install and is safe to re-run. It
installs `uv`, then `ansible-core` and the pinned Galaxy collections, clones this
repository to `~/.dotfiles`, seeds `inventory/group_vars/all.yml` from the
example, and applies the playbook.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)"
```

Note the `bash -c "$(curl ...)"` form rather than `curl | bash`: it passes the
script as an argument, so stdin stays on the terminal and `sudo` can prompt.

Which roles run is decided by `dotfiles_roles` in
`inventory/group_vars/all.yml`. Re-runs take arguments:

```bash
~/.dotfiles/scripts/setup --tags zsh,git      # only these roles
~/.dotfiles/scripts/setup --tags configure    # only config, no installs
~/.dotfiles/scripts/setup --check --diff      # preview, change nothing
~/.dotfiles/scripts/setup --skip-tags update  # skip the apt upgrade
~/.dotfiles/scripts/setup --help
```

Run logs are kept in `~/.local/state/dotfiles/`.

### Secrets

I am using Bitwarden integration with Ansible to retrieve secrets from Secrets Manager and inject them into the Ansible playbook. The lookup plugin will inject retrieved secrets as masked environment variables inside an Ansible playbook. To setup the collection:

`scripts/setup` installs the SDK into the `ansible-core` environment
(`uv tool install --with bitwarden-sdk`), which is required because the lookup
runs controller-side and must be importable by the interpreter running
`ansible-playbook`. Only the token needs setting:

```bash
export BWS_ACCESS_TOKEN="<your-bws-access-token>"
```

### Setup

`scripts/setup` seeds `inventory/group_vars/all.yml` automatically on a fresh
clone, filling in the user, home directory and hostname. To do it by hand, or
to reset it, copy the [example](https://github.com/irish1986/dotfiles/blob/main/docs/examples/group_vars-all.yml) and adjust it. `all.yml` is
gitignored because it holds machine identity.

```bash
cp ~/.dotfiles/docs/examples/group_vars-all.yml ~/.dotfiles/inventory/group_vars/all.yml
```

## Reference

This repo is heavily influenced by:

 1. [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles)
 2. [TechDufus](https://github.com/TechDufus/dotfiles)
