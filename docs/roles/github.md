# github

The GitHub CLI and its global configuration.

## Split out of the git role

`gh` used to be installed by the `git` role, behind a `git_install_gh` flag. That put an apt repository and a package that have nothing to do with git inside the role that configures `~/.gitconfig`, and left `~/.config/gh` configured by nobody.

The apt repository keeps its original name, `github-cli`, so a machine the `git` role already provisioned reuses `/etc/apt/sources.list.d/github-cli.sources` in place rather than collecting a second copy under a new name. There is nothing to clean up on upgrade.

The role is in the default selection rather than the opt-in block, because `git_install_gh` defaulted to `true` -- moving it opt-in would have quietly removed `gh` from every machine.

## gh comes from GitHub, not the archive

jammy has no `gh` package at all -- it first appeared in 23.04 -- so a plain `apt: name=gh` fails outright on 22.04. noble has one, pinned at 2.45 while upstream is far ahead.

## Configuration goes through gh

`github_config` is applied with `gh config set`, mirroring how the `git` role drives `git_config` through `git config` rather than writing `~/.gitconfig` directly.

Templating `~/.config/gh/config.yml` would not hold: `gh` rewrites that file itself and maintains a `version` key of its own, so the template and the tool would overwrite each other on alternating runs. Reading each key back with `gh config get` first is also what keeps the run idempotent, since `gh config set` has no notion of "already set".

`GH_CONFIG_DIR` is set explicitly on every `gh` invocation. Without it, `gh` resolves its own configuration directory from `XDG_CONFIG_HOME`, which need not agree with `github_config_dir` -- the role would create one directory and write into another.

Aliases are compared against `gh alias list`, which prints one `name: expansion` line per alias, so matching the whole line catches a changed expansion as well as a missing alias. `--clobber` is required because a plain `gh alias set` fails on an alias that already exists.

## Authentication is not managed here

`gh auth login` is interactive and writes `hosts.yml` in the same directory. The role configures preferences only; log in once, by hand.
