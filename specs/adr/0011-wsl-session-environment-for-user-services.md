# WSL environment for user services

Status: accepted, 2026-10-21

WSL hands its own environment only to processes it starts through `wsl.exe`: the Windows PATH, which `appendWindowsPath` appends, and `WSL_DISTRO_NAME`. A systemd `--user` service starts from the user manager and never gets them. herdr runs that way, and every terminal shell is a herdr pane, so in practice no shell had them: `code .` was not found, git's `code --wait` editor failed, and the WSL block in `.zshaliases` (`pbcopy`, `open`, `winhome`) was skipped silently, because it checks `WSL_DISTRO_NAME`. Running a Windows binary by its full path still worked: interop goes through binfmt, not the environment.

The system role puts both back in `~/.config/environment.d/999-wsl.conf`. The systemd user manager reads that file when it starts, so herdr and every other user service get the values. The run reads the distro name from `wslpath -w /` and the Windows PATH from `cmd.exe`, with each entry translated by `wslpath -u`. The PATH line is written only while `appendWindowsPath` and interop are on, so turning them off in the defaults still means what it says. The file's name sorts after `/etc/environment` (`/usr/lib/environment.d/99-environment.conf`), which sets PATH outright, and after snapd's `990-snapd.conf`, so the Windows entries come last, where WSL itself would put them.

Two alternatives were rejected:

- `Environment=` lines in herdr's unit would fix herdr alone.
- Working the values out in `.zshenv` would run `cmd.exe` on every shell start, at roughly 100 ms or more each time.

`WSL_INTEROP` is left out: it names one session's socket and goes stale, and interop works without it. VS Code's `code` script sets `WSLENV` itself.

## Consequences

- The Windows PATH is a snapshot taken when the playbook runs. Windows-side installs that add to it are missing until the next run.
- The user manager reads the file only at its own start. A change applies once the distro restarts (`wsl --terminate <distro>`), and the run prints a reminder instead of restarting herdr, which would kill every pane, including the one running the playbook.
- The verify step parses the file with systemd's own environment generator, not the running manager, so it passes before the restart.
