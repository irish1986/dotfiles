# Windows and WSL

The boundary is deliberately narrow: one fact decides whether the machine is WSL,
and one role owns everything Windows-side.

## Detection

```yaml
dotfiles_is_wsl: >-
  {{ (ansible_virtualization_type | default('') == 'wsl')
     or (ansible_kernel is search('(?i)microsoft')) }}
```

Two signals, because neither is reliable alone. `ansible_virtualization_type`
reports `wsl` on some ansible-core versions and `container` on others — 2.16.3
reports `container` on WSL2 — so the kernel string is the dependable one, and it
covers WSL1 (`...-Microsoft`) as well as WSL2 (`...-microsoft-standard-WSL2`).

This used to be a shell-out to `cat /proc/version` whose result was stored as the
**string** `"true"` or `"false"`. A non-empty string is truthy in Jinja, so
`when: not ansible_host_environment_is_wsl` evaluated False on *every* host:

```console
$ ansible localhost -m debug -a 'msg={{ not v }}' -e '{"v":"false"}'
    "msg": "False"
$ ansible localhost -m debug -a 'msg={{ not v }}' -e '{"v":"true"}'
    "msg": "False"
```

Two roles had therefore never run, and a Docker restart handler had never fired.
Every consumer now uses `| bool` explicitly so a stringly-typed value cannot
silently invert a gate again.

## systemd, not "not WSL"

Service tasks gate on `dotfiles_has_systemd`, never on WSL. WSL2 with
`systemd=true` in `wsl.conf` *does* have systemd and *does* want Docker enabled;
a CI container has none. The old `not is_wsl` check expressed neither, which is
why Docker was installed but never enabled on this machine.

## Windows path detection

The Windows profile is resolved at runtime rather than hardcoded:

```yaml
- name: WSL | Query USERPROFILE
  ansible.builtin.command:
    cmd: "{{ wsl_cmd }} /c echo %USERPROFILE%"
    chdir: /mnt/c
```

`chdir: /mnt/c` is mandatory. Run from a WSL path, `cmd.exe` emits three lines of
UNC warning on stdout *before* the value.

The **path** is resolved, not the user name, then the name is derived from it.
That survives `C:\Users\name.DOMAIN`, redirected profiles and a non-`C:` profile
drive. PowerShell is the fallback; `wslpath -u` translates the result.

Interop tasks use absolute paths to `cmd.exe` and `powershell.exe` rather than
relying on `PATH`, so the role keeps working if `appendWindowsPath` is turned off.

## Interop versus WSL

`/run/WSL` decides whether Windows-side tasks run. It is present whenever the
interop server is, and absent when `[interop] enabled=false` — which is the real
precondition, rather than merely being inside WSL.

## Modes on /mnt/c

`[automount] metadata` is the highest-value option in `wsl.conf`. Without it every
file under `/mnt/c` reports mode `0777`, so git treats mode changes as diffs and
`chmod` is a no-op.

The consequence is that once `metadata` is on, an Ansible `mode:` on a `/mnt/c`
path really does apply — which is why **no task in this repository sets a mode on
a Windows-side file**. A restrictive Linux mode on a Windows file is not useful.

## Hostname

On WSL the hostname belongs to `[network] hostname` in `wsl.conf`. The
`ansible.builtin.hostname` module's change does not survive a `wsl --shutdown`,
which is why a machine configured that way reverts to the Windows computer name.
The `system` role therefore only manages the hostname when *not* on WSL.
