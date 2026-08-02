# zsh

Zsh, oh-my-zsh, its plugins, and the shell dotfiles.

Runs after [fonts](fonts.md) and [wsl](wsl.md) in `dotfiles_roles`: `.p10k.zsh` selects a `nerdfont-v3` prompt, which renders as mojibake until a Nerd Font is installed on the Windows side.

Setting zsh as the **login shell** is not this role's job -- the [user role](user.md) owns the account, and runs immediately after this one so that `/usr/bin/zsh` exists by the time it is set. This role installs the package and the dotfiles.

## Dotfiles

`.zshrc`, `.zshaliases`, `.zshfunc` and `.p10k` (deployed as `~/.p10k.zsh`).

Two of those had never been deployed. `.p10k` was committed for months and never copied, under a name `.zshrc` did not source; `.zshfunc` was deployed but never loaded, so `extract`, `mkdirg` and the rest were dead.

`.zshrc` guards every `source` and `eval`, so a shell opened before the playbook finishes does not print errors on every prompt. It no longer re-sources `~/.zshenv`, which zsh loads automatically and first.

## Secrets

This role absorbed the deleted `env` role, so `~/.zshenv` has a single owner. Previously `zsh` deployed a literal `.zshenv` while `env` wrote real tokens into the same file with `blockinfile`, and whichever ran last won.

Off by default; see [Secrets](../getting-started/secrets.md). The rendered block is written with `no_log: true`.

## Plugins

Every plugin is pinned. These are vendored dependencies, and an unpinned clone means a shell whose behaviour changes with no commit to this repository.

The oh-my-zsh installer runs as the login user, not root. Under the old global `become` it ran as root, which is what left every file under `~/.oh-my-zsh/custom` root-owned -- about 1090 files, including the user's own `.gitconfig` and `.zsh*`.

`eza` is only in the archive from 24.04, so `vars/Ubuntu-22.yml` drops it on jammy where the `zsh-eza` plugin has no binary to wrap.
