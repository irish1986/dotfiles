# Prerequisites

## Supported targets

| Ubuntu | Status |
| --- | --- |
| 22.04 LTS | Supported |
| 24.04 LTS | Supported, primary target |
| 26.04 LTS | Supported |
| 20.04 LTS | Not supported; standard support ended April 2025 |

Anything that is not Ubuntu is refused. A Debian-like system will prompt and then be rejected by the playbook's own distribution assert, because no role has been tested there.

`scripts/setup` also requires:

- `bash` 4.4 or newer
- `sudo`, with your account able to use it
- a non-root user; the script refuses to run as root, since it provisions the invoking user's home directory

## Windows and WSL2

The primary target is WSL2 on Windows 11. To get that far:

```powershell
wsl --install -d Ubuntu-24.04
```

Then open the distro, create your user, and run the bootstrap command. Install [Windows Terminal](https://aka.ms/terminal) first if you do not have it — the playbook manages its settings but will not install it.

Everything Windows-side that the playbook manages is described under [Windows and WSL](windows-wsl.md).

## Bare metal or a VM

The playbook works outside WSL. Roles that only make sense on WSL detect that and skip; the `vscode` role does the opposite, installing a native build only when *not* on WSL, since on WSL you use the Windows build through Remote-WSL.
