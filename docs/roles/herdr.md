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

The shipped config binds no plugin actions -- every `[[keys.command]]` block is commented out. Plugins are **not** installed by this role either, and herdr keeps them per user in its own store, so a fresh machine has none. That is a gap worth closing with a `herdr_plugins` list once the plugin set stops moving.

## Not the curl | sh one-liner

Upstream's install is `curl -fsSL https://herdr.dev/install.sh | sh`. This role does the same work in Ansible instead, for two reasons:

- The script always installs whatever the manifest calls latest, so `herdr_version` could not pin anything.
- It has no idempotence guard, so every playbook run would re-download ~20 MB and report changed.

The role reads the same `latest.json` manifest the script and `herdr update` read, so an Ansible install and an in-place `herdr update` agree on what latest means. That manifest also carries the asset URL, which keeps the unpinned path from guessing a filename upstream might rename, and avoids the GitHub API's unauthenticated rate limit entirely.

## Version handling

`herdr_version` is **pinned** by default. herdr is not an ordinary tool here: native agent-session restore carries a per-agent minimum herdr version, so a floating multiplexer can change restore behaviour under a session that is already open. Set it to `""` to resolve the manifest's version instead; the pinned path builds the release URL from `herdr_download_base` rather than the manifest, and accepts the version with or without the leading `v`.

Because Ansible owns which release is on disk, `config.toml` sets `[update] version_check = false` and `manifest_check = false`. `herdr update` would move the binary out from under the playbook, and the update nag is noise while pinned.

The guard compares `herdr --version` against the resolved version, not merely whether the binary exists -- which is what [uv](uv.md) and [fluxcd](fluxcd.md) do, because their installers are the only thing that can drive them. A converged machine downloads nothing; a new upstream release installs on the next run.

## No published checksum

Unlike [snyk](snyk.md), herdr publishes no `.sha256` beside its assets, so there is nothing to verify against automatically. The download is HTTPS from `github.com` and that is the whole of the integrity story.

`herdr_checksum` is the escape hatch: set it to a sha256 hex digest, alongside a pinned `herdr_version`, and `get_url` verifies before the binary is moved into place.

## PATH

The binary lands in `~/.local/bin` -- the same directory [uv](uv.md) and [prek](prek.md) install into. That directory used to reach `PATH` only through uv's `~/.local/bin/env`, which `.zshrc` sources: interactive-only, and absent on a host where the uv role never ran. The autostart block below now puts it on `PATH` in `~/.zshenv` instead, which zsh reads for every shell.

Nothing needs `become` for the binary itself; herdr is a per-user program. The one root-owned task in the role is `loginctl enable-linger`, which lives in the install phase because `/var/lib/systemd/linger/` is system state.

## Autostart

`herdr_autostart` (default true) writes a marker block into `~/.zshenv` so a terminal window opens straight into the persistent session:

```zsh
if [[ -o login && -o interactive && -z $HERDR_ENV \
      && ${HERDR_AUTOSTART:-1} != 0 && -x /home/<user>/.local/bin/herdr ]]; then
  exec /home/<user>/.local/bin/herdr
fi
```

`~/.zshenv` rather than `~/.zshrc`, because zsh reads it first and for every shell: the `exec` lands before the p10k instant prompt, oh-my-zsh and `compinit`, so a shell that is about to be replaced never pays for them. The [zsh](zsh.md) role already manages a marker block in the same file for secrets, and role order puts `zsh` before `herdr`, so those exports are in the environment before the `exec` runs.

Four guards, each doing separate work:

| Guard | Excludes |
| --- | --- |
| `-o login` | herdr's own pane shells. `[terminal] shell_mode = "auto"` makes them non-login on Linux, so they never re-enter. |
| `-o interactive` | `zsh -c` in scripts, Ansible, and editor tooling. |
| `-z $HERDR_ENV` | anything herdr-managed, belt to the `-o login` braces. The equivalent of tmux's `$TMUX`. |
| `-x <binary>` | a host where the install phase has not run yet, so the block is inert rather than fatal. |

The net effect on this machine: Windows Terminal enters herdr, VS Code's integrated terminal and `zsh -i -c` stay plain zsh, and an inbound ssh -- a login shell -- attaches to the same session.

`exec` means detaching (`ctrl+space q`) closes the window while the server and every agent in it keep running. If the client is ever wedged, `HERDR_AUTOSTART=0 zsh -l` gets a plain login shell without touching the playbook; setting `herdr_autostart: false` and re-running removes the block entirely.

## Session persistence

This is where herdr differs most from a tmux setup, and the mapping is worth stating explicitly:

| tmux | herdr | Where it is configured |
| --- | --- | --- |
| tmux-continuum keeping the server alive | the resident background server: survives detach and a closed window, dies on `wsl --shutdown` | nothing to configure |
| continuum auto-start at boot | `herdr.service`, a `systemd --user` unit | `herdr_manage_service`, `herdr_linger` |
| tmux-resurrect session shape | `session.json` -- workspaces, tabs, panes, cwd, layout, focus | automatic on server start |
| tmux-resurrect pane contents | `session-history.json` | `[experimental] pane_history` |
| resurrect strategy hooks | native agent resume (`claude --resume <id>` and equivalents) | `[session] resume_agents_on_restore` |

A server restart restores the *shape*, not the processes: shells come back as new shells in their saved directories. Only supported agents resume their actual conversation, and only when herdr captured a native session reference for them.

### The systemd user unit

`herdr_manage_service` (default true, skipped where `dotfiles_has_systemd` is false) renders `~/.config/systemd/user/herdr.service` and enables it, so the server comes up at boot and has already restored `session.json` before anything attaches. `herdr_linger` runs `loginctl enable-linger`, without which the user manager stops at logout and the unit would only ever start on first login -- which would defeat the point.

The role **enables** the unit and deliberately does not start it. By the time the playbook gets there a server is usually already running -- the one that spawned the shell running the playbook -- and starting a second would either collide on `herdr.sock` or adopt and restart the first, killing every live pane. The unit takes over at the next boot, which is the only moment there is nothing to lose. So `verify` asserts the unit is enabled and merely reports whether it is active.

The unit's handler does `daemon-reload` and nothing else. There is deliberately no restart handler, for the same reason `config.toml` has none: `systemctl --user restart herdr` kills every live pane and any agent inside it. Picking up a changed unit is a deliberate act.

### pane_history

`[experimental] pane_history = true` in the shipped config is the closest thing to tmux-resurrect's saved pane contents. Upstream defaults it **off**, and the reason is worth repeating: the capture lands in `~/.config/herdr/session-history.json` in plaintext, beside `session.json`, and pane output can include secrets, tokens, prompts and command output. Set it back to `false` in `roles/herdr/files/config.toml` if that trade is wrong for a given machine.
