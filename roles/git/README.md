# git

git, git-lfs, the GitHub CLI, and the global git configuration.

## gh comes from GitHub, not the archive

jammy has no `gh` package at all -- it first appeared in 23.04 -- so the previous
`apt: name=gh` failed outright on 22.04. noble has it, but pinned far behind
upstream. The GitHub CLI apt repository is configured instead.

## Commit signing

Signing uses SSH keys rather than GPG (`gpg.format = ssh`). The public key is
added to `~/.ssh/allowed_signers` with a `blockinfile` marker keyed on the email
address, so rotating a key replaces that signer's line instead of appending a
second one.

## git-filter-repo

Replaces the deleted `bfg` role: same job, no JRE, and packaged from 24.04. The
`bfg` alias in `.zshaliases` now points at it.

## Configuration

`git_config` in `defaults/main.yml` is written verbatim into `~/.gitconfig`, so it
can be extended or overridden from `group_vars`. Paths that must be absolute are
computed separately in `vars/main.yml`.

`core.autocrlf` is deliberately `false`: this is a Linux checkout even when the
host is Windows.
