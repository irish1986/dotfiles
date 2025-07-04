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

This playbook includes a custom shell script located at `scripts/dotfiles`.  This shell script is used to initialize your environment after installing `Ubuntu`.  It is not mandatory but recommended to perform a full system upgrade although recommended.  By default, the only included roles is `update`.  Ansible Galaxy dependencies collection are installed automatically although given some issue occurs, you can run it maually as following.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)"
```

### Secrets

I am using Bitwarden integration with Ansible to retrieve secrets from Secrets Manager and inject them into the Ansible playbook. The lookup plugin will inject retrieved secrets as masked environment variables inside an Ansible playbook. To setup the collection:

```bash
pip install bitwarden-sdk
export BWS_ACCESS_TOKEN="<your-bws-access-token>"
```

### Setup

The `sample.yml` [file](https://raw.githubusercontent.com/irish1986/dotfiles/main/inventory/group_vars/sample.yml) contains an exemple configuration.  Create a copy of this named `all.yml` and make the recommended ajustment.

```bash
cp ~/.dotfiles/inventory/group_vars/sample.yml ~/.dotfiles/inventory/group_vars/all.yml
```

## Reference

This repo is heavily influenced by:

 1. [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles)
 2. [TechDufus](https://github.com/TechDufus/dotfiles)
