# user

Login user privileges, groups, shell and home directory scaffolding.

Before this role existed, all of that was spread across four roles that each acquired a piece for local reasons: the sudoers drop-in was in [system](system.md), the login shell in [zsh](zsh.md), the docker group in [docker](docker.md), `~/.config` in system and `~/.local/bin` in [wsl](wsl.md). Nothing owned the user.

The account itself is **not** created here. `scripts/setup` refuses to run as root and provisions the invoking user, so by the time any role runs the user already exists. This role configures it.

## Groups are created, not skipped

`user_groups` lists the groups the login user joins, and each one is created with `ansible.builtin.group` before the membership is applied.

The obvious alternative -- skip a group that does not exist yet and pick it up next time -- fails CI. The `converge` job runs `scripts/setup` twice and asserts `changed=0` on the second run, so a membership deferred to run 2 reports `changed` there and the job goes red. Creating the group makes a single run converge.

Pre-creating `docker` before the docker role installs is safe: the package's postinst only calls `addgroup` when the group is absent, so it adopts the existing one. The only visible difference is a GID above 1000 rather than in the system range.

Membership is real in the group database immediately, but not in any shell session that was already open. `scripts/setup` says so at the end of a run; that is a login-session limitation, not something this role can fix.

## The login shell is guarded

`user_shell` is applied only when the binary actually exists, which is why the role is listed **after** `zsh` in `dotfiles_roles`.

The zsh role set the shell unconditionally. If the package had ever failed to install, that would write a path into `/etc/passwd` that does not resolve -- and a login shell that does not exist is not a problem you can log in to fix.

`verify.yml` reads the shell back out of `getent passwd`. Nothing did that before, so a change that silently failed looked exactly like one that worked.

## Home directories

`user_directories` is a list of `{path, mode}` relative to `dotfiles_home`, covering `~/.cache`, `~/.config`, `~/.local/bin`, `~/.local/share` and `~/.local/state`.

The modes match what Ubuntu already creates, so running this against a provisioned machine never widens a directory that was private. `.config` and `.local/bin` are `0755` -- what the system role and the uv installer leave them -- and the rest are `0700`. The single deliberate change is `~/.local/state`, which Ubuntu leaves `0755` and which holds logs and shell history.

`~/.local/bin` is the one that mattered. [uv](uv.md), [prek](prek.md), [ansible_tools](ansible_tools.md) and [copilot](copilot.md) all resolve binaries out of it, and the only thing that created it was the wsl role, behind a `wsl_manage_win32yank` flag. On a non-WSL host it existed purely because two upstream installers happened to `mkdir` it themselves.

**The wsl role still creates it too, and that is deliberate.** `wsl` runs before `user` and copies win32yank into that directory in the same task file; it cannot depend on a role that has not run yet. Two roles creating one directory with identical owner and mode is idempotent.

Directories that belong to a single application -- `~/.kube`, `~/.claude`, `~/.copilot`, `~/.config/gh` -- stay with the role that writes into them, because their modes are set by what the application requires rather than by any convention here. `~/git/<login>` stays with [git](git.md), since it is keyed on `git_user_login`.

## sudo

The drop-in path is unchanged from when system owned it, so an already-provisioned machine reuses `/etc/sudoers.d/90-dotfiles` rather than collecting a second file.

Both the `%sudo` line and the drop-in are written with `validate: visudo -cf %s`, and `verify.yml` re-checks the installed file afterwards. A malformed sudoers file locks the machine out of sudo entirely, which is worth asserting rather than assuming the earlier validate held.

The bootstrap side stays in `scripts/setup`, which warms an interactive sudo ticket for the first run. After one successful run this role grants NOPASSWD and the prompting stops.
