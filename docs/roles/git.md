# git

git, git-lfs, and the global git configuration.

`gh` used to be installed here, behind a `git_install_gh` flag. It now has its own role: see [github](github.md). One role owns the `github-cli` apt source, and it is the one that also configures `~/.config/gh`.

## Commit signing

Signing uses SSH keys rather than GPG (`gpg.format = ssh`). The public key is added to `~/.ssh/allowed_signers` with a `blockinfile` marker keyed on the email address, so rotating a key replaces that signer's line instead of appending a second one.

## git-filter-repo

Replaces the deleted `bfg` role: same job, no JRE, and packaged from 24.04. The `bfg` alias in `.zshaliases` now points at it.

## Configuration

`git_config` in `defaults/main.yml` is written verbatim into `~/.gitconfig`, so it can be extended or overridden from `group_vars`. Paths that must be absolute are computed separately in `vars/main.yml`.

`core.autocrlf` is deliberately `false`: this is a Linux checkout even when the host is Windows.
