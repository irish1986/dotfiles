# dotfiles

![dotfiles-logo](https://github.com/TechDufus/dotfiles/assets/46715299/6c1d626d-28d2-41e3-bde5-981d9bf93462)

<p align="center">
    <a href="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml"><img align="center" src="https://github.com/irish1986/dotfiles/actions/workflows/ci.yml/badge.svg" alt="ci pipeline"></a>
    <a href="https://github.com/irish1986/dotfiles/issues"><img align="center" src="https://img.shields.io/github/issues/irish1986/dotfiles" alt="issues"></a>
    <a href="https://github.com/irish1986/dotfiles/pulls"><img align="center" src="https://img.shields.io/github/issues-pr/irish1986/dotfiles" alt="pull requests"></a>
    <a href="https://github.com/irish1986/dotfiles/commits/main"><img align="center" src="https://img.shields.io/github/commit-activity/m/irish1986/dotfiles" alt="commit frequency"></a>
</p>

---

## Goals

Provide idempotent fully automated deployment mechanism for my computers from a versioned controlled source targeting `Ubuntu|Windows` that is easy to set up and maintain.

## Getting Started

### System Upgrade

Verify your `Ubuntu|Windows` installation has all latest packages installed before running the playbook.  OTE: This might take some time.

```bash
# Ubuntu
sudo apt-get update && sudo apt-get upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
```

```powershell
# Windows
Install-Module PSWindowsUpdate
Get-WindowsUpdate
Install-WindowsUpdate
```

### Setup

The `default.yml` [file](https://raw.githubusercontent.com/irish1986/dotfiles/main/inventory/group_vars/default.yml) contains generic variable required for common setup.  These can be modified but not often.

The `all.yml` [file](https://raw.githubusercontent.com/irish1986/dotfiles/main/inventory/group_vars/all.yml) allows you to personalize your setup to your needs.  These settings are system wide configurations mostly based on user and accounts.

The role `default.yml`. This file will be created in the file located at `~/.dotfiles/inventory/group_vars/all.yaml`.  After all setup configuration is complete, you can cntinue to [Install this dotfiles](#install) and including your desired settings.

### Secrets

The `vault.secret` file allows you to encrypt values with `Ansible vault` and store them securely in source control. Create a file located at `~/.config/dotfiles/vault.secret` with a secure password in it.

```bash
vim ~/.ansible-vault/vault.secret
```

To then encrypt values with your vault password use the following:

```bash
ansible-vault encrypt_string --vault-password-file $HOME/.ansible-vault/vault.secret "mynewsecret" --name "MY_SECRET_VAR"
cat myfile.conf | ansible-vault encrypt_string --vault-password-file $HOME/.ansible-vault/vault.secret --stdin-name "myfile"
```

> NOTE: This file will automatically be detected by the playbook when running `dotfiles` command to decrypt values. Read more on Ansible Vault [here](https://docs.ansible.com/ansible/latest/user_guide/vault.html).

### Install

This playbook includes a custom shell script located at `scripts/dotfiles`. This script is added to your $PATH after installation and can be run multiple times while making sure any Ansible dependencies are installed and updated.

This shell script is also used to initialize your environment after installing `Ubuntu|Windows` and performing a full system upgrade as mentioned above.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/dotfiles)"
```

### Update

This repository is continuously updated with new features and settings which become available to you when updating.

To update your environment run the `dotfiles` command in your shell:

```bash
dotfiles
```

This will handle the following tasks:

- Verify Ansible is up-to-date
- Generate SSH keys and add to `~/.ssh/authorized_keys`
- Clone this repository locally to `~/.dotfiles`
- Verify any `ansible-galaxy` plugins are updated
- Run this playbook with the values in `~/.config/dotfiles/group_vars/all.yaml`

## Reference

This repo is heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles) and [TechDufus](https://github.com/TechDufus/dotfiles)'s repo. Go check them out !
