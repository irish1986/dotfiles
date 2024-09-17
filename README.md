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

Provide idempotent deployment mechanism for my computers from a versioned controlled source targeting `Ubuntu` that is easy to set up and maintain.

## Getting Started

### System Upgrade

Verify your `Ubuntu` installation has all latest packages installed before running the playbook.  OTE: This might take some time.

```bash
# Ubuntu
sudo apt-get update && sudo apt-get upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
```

### Setup

The `sample.yml` [file](https://raw.githubusercontent.com/irish1986/dotfiles/main/inventory/group_vars/sample.yml) contains generic variable required for common setup.  These can be modified but not often.

### Install

This playbook includes a custom shell script located at `scripts/dotfiles`. This script is added to your $PATH after installation and can be run multiple times while making sure any Ansible dependencies are installed and updated.

This shell script is also used to initialize your environment after installing `Ubuntu` and performing a full system upgrade as mentioned above.

```bash
# Ubuntu
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)"
```

## Reference

This repo is heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles) and [TechDufus](https://github.com/TechDufus/dotfiles)'s repo. Go check them out !
