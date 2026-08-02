# Windows and WSL

The `wsl` role manages everything that crosses into Windows. It is a no-op off WSL, and **nothing in it needs administrator rights**.

## What it manages

| Thing | Where |
| --- | --- |
| `wsl.conf` | `/etc/wsl.conf` |
| `.wslconfig` | `%USERPROFILE%\.wslconfig` |
| Windows Terminal settings | merged into the live `settings.json` |
| Nerd Fonts | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` + `HKCU` |
| Clipboard bridge | `win32yank.exe` in `~/.local/bin` |

## Restart required

Changes to `wsl.conf` and `.wslconfig` do not apply until WSL restarts. Ansible prints a reminder when either changed. Run this from PowerShell or CMD — **not** from inside the distro, where it would terminate the playbook:

```powershell
wsl --shutdown
```

To make an existing disk sparse (the `sparseVhd` setting only affects newly created disks), with the distro stopped:

```powershell
wsl --manage Ubuntu-24.04 --set-sparse true
```

## Windows Terminal

Only `profiles.defaults` and the scalar globals are managed. `profiles.list`, `actions`, `keybindings`, `schemes` and `themes` are left alone, so anything you change in the Terminal UI survives.

That split is deliberate. The merge uses `combine(recursive=true)`, which deep-merges dicts but **replaces lists wholesale** — managing `keybindings` would silently revert every binding you added. And the profile you actually use comes from the AppX generator, whose GUID is not reproducible from any documented formula, so a templated `settings.json` cannot express it. The default profile is resolved by inspecting the live profile list instead.

The first run takes a backup beside the file.

## Fonts

Installed on both sides: `~/.local/share/fonts` for Linux (fontconfig, WSLg apps, matplotlib) and `%LOCALAPPDATA%\Microsoft\Windows\Fonts` plus the matching `HKCU` registry values for Windows. Per-user, so no elevation.

A font file already loaded by a running process cannot be replaced. When that happens the run reports which fonts were left at their existing version and continues — the registry entry is still reconciled, because a file being present is not the same as Windows knowing about it. Close Terminal and re-run `--tags wsl` to update them.

## Clipboard

tmux copies through OSC 52, which Windows Terminal supports natively — no helper binary, no X server, and it works over SSH and through nested tmux.

For the shell, `pbcopy` and `pbpaste` are wired to `win32yank`. That is the only clean paste path:

```console
$ printf 'hello' | clip.exe && powershell.exe -Command "Get-Clipboard" | cat -A
hello^M$          # CR plus a spurious newline, even with -Raw
$ win32yank.exe -o --lf | cat -A
hello             # clean
```

PowerShell's output pipeline appends its own newline, which `-Raw` does not suppress.

## Interop PATH

`appendWindowsPath` is left **on** by default. Turning it off is the largest interactive-latency win available — it removes roughly 24 DrvFs directories that `compinit`, `command-not-found` and every `command -v` must walk — but it breaks `docker.exe`, `dotnet`, `gh.exe`, chocolatey shims and the Tailscale CLI.

To try it:

```yaml
wsl_interop_append_windows_path: false
```

then add back the specific paths you need in `.zshenv`, and `wsl --shutdown`. The role's own interop tasks use absolute paths to `cmd.exe` and `powershell.exe`, so they keep working either way.

## SSH keys

The default is a WSL-native key: independently revocable, no Windows-side change. To seed from the Windows key instead:

```yaml
ssh_import_from_windows: true
```

The copy is `force: false`, so it seeds an empty `~/.ssh` but can never overwrite a key generated locally. An earlier version overwrote on every run, which meant the bootstrap script and the role fought over the same file.
