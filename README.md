# dotfiles

This repo contains the configuration to setup my machines. This is using [Chezmoi](https://chezmoi.io), the dotfile manager to setup the install.

This automated setup is currently only configured for Fedora machines.

## How to run

```shell
export GITHUB_USERNAME=irish1986
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --ssh --apply $GITHUB_USERNAME
```
