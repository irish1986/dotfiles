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

Provide idempotent deployment mechanism for my computers from a versioned controlled source targeting `Ubuntu` that is easy to set up and maintain.  I am mostly using this setup with WSL2 on Windows 11 to sync various workstation and laptops; both for personal and professional usage.

## Getting Started

### Generate ssh-key

You will need to add a valid ssh-key to your GitHub account.  I am still working on automating this.

```bash
ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C $USER@$HOSTNAME
```

### Install

This playbook includes a custom shell script located at `scripts/dotfiles`.  This shell script is used to initialize your environment after installing `Ubuntu`.  It is not mandatory but recommended to perform a full system upgrade although recommended.  By default, the only included roles is `update`.  Ansible Galaxy dependencies collection are installed automatically although given some issue occurs, you can run it maually as following.

```bash
sudo apt-get update && sudo apt-get upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
ansible-galaxy install -r ~/.dotfiles/collections/requirements.yml
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)"
```

### Setup

The `sample.yml` [file](https://raw.githubusercontent.com/irish1986/dotfiles/main/inventory/group_vars/sample.yml) contains an exemple configuration.  Create a copy of this named `all.yml` and make the recommended ajustment.

```bash
cp ~/.dotfiles/inventory/group_vars/sample.yml ~/.dotfiles/inventory/group_vars/all.yml
```

## To Do

A quick list of todo's I need to automate.

 1. `pipx ensurepath`
 2. `ggshield auth login`
 3. Tmux TPM repo install issue
 4. CHOWN -R user:group ~/.config issue

## Reference

This repo is heavily influenced by:

 1. [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles)
 2. [TechDufus](https://github.com/TechDufus/dotfiles)
