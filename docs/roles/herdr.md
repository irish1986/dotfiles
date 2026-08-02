# herdr

[herdr](https://herdr.dev) is a terminal multiplexer built around coding agents: persistent sessions, panes and workspaces like [tmux](tmux.md), plus agent state in the sidebar and a CLI for driving agents in panes. Sessions survive a closed laptop, so an ssh from elsewhere reattaches to the same herd.

Installed from the upstream GitHub release binary into `~/.local/bin`.

## It does not replace tmux by being enabled

Both roles can be selected at once and they do not collide: different binaries, different config directories, no shared files. Enabling herdr changes nothing about tmux, and `dotfiles_roles` is where the decision to drop one of them gets made -- delete the line, and the next run simply stops managing it. Neither role uninstalls the other's package or config, so switching is reversible by editing one list.

Both ship their config from the repository: `tmux.conf` for one, `config.toml` for the other.

## config.toml

`roles/herdr/files/config.toml` is copied to `~/.config/herdr/config.toml` -- the same arrangement as tmux, so the file in git is the source of truth and a local edit is reverted on the next run. Edit the repository copy, not the deployed one.

Two things worth knowing about that directory:

- It is herdr's **runtime** directory as well as its config directory: `herdr.sock`, `session.json`, `plugins.lock` and the client and server logs all live there. The role writes `config.toml` and nothing else, and never cleans the directory out.
- The running server holds its own copy of the config, so a deployed change takes effect the next time `herdr` starts. There is deliberately no handler restarting it -- that would kill live panes and any agent running inside them in order to apply a theme.

The shipped config binds `cmd+r` and `cmd+e` to plugin actions (`persiyanov.reviewr`, `herdr-file-viewer`). Plugins are **not** installed by this role, and herdr keeps them per user in its own store, so on a fresh machine those two keys do nothing until the plugins are installed. That is a gap worth closing with a `herdr_plugins` list once the plugin set stops moving.

## Not the curl | sh one-liner

Upstream's install is `curl -fsSL https://herdr.dev/install.sh | sh`. This role does the same work in Ansible instead, for two reasons:

- The script always installs whatever the manifest calls latest, so `herdr_version` could not pin anything.
- It has no idempotence guard, so every playbook run would re-download ~20 MB and report changed.

The role reads the same `latest.json` manifest the script and `herdr update` read, so an Ansible install and an in-place `herdr update` agree on what latest means. That manifest also carries the asset URL, which keeps the unpinned path from guessing a filename upstream might rename, and avoids the GitHub API's unauthenticated rate limit entirely.

## Version handling

`herdr_version` is empty by default and resolves to the manifest's version. Set it to pin (`0.7.5`, with or without the leading `v`); the pinned path builds the release URL from `herdr_download_base` rather than the manifest.

The guard compares `herdr --version` against the resolved version, not merely whether the binary exists -- which is what [uv](uv.md) and [fluxcd](fluxcd.md) do, because their installers are the only thing that can drive them. A converged machine downloads nothing; a new upstream release installs on the next run.

## No published checksum

Unlike [snyk](snyk.md), herdr publishes no `.sha256` beside its assets, so there is nothing to verify against automatically. The download is HTTPS from `github.com` and that is the whole of the integrity story.

`herdr_checksum` is the escape hatch: set it to a sha256 hex digest, alongside a pinned `herdr_version`, and `get_url` verifies before the binary is moved into place.

## PATH

The binary lands in `~/.local/bin`, which `.zshrc` already puts on `PATH` ahead of `/usr/bin` -- the same directory [uv](uv.md) and [prek](prek.md) install into. Nothing needs `become`; herdr is a per-user program, not a system service.
