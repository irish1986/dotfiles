# system

Hostname, sudoers, base packages and the `~/.config` directory.

## sudoers

The passwordless grant is a validated drop-in at `/etc/sudoers.d/90-dotfiles`,
mode `0440`.

It used to be a `blockinfile` on `/etc/sudoers` with **no `validate:`**, so a bad
render locked the machine out of sudo. Its `insertafter` regex (`"%sudo   ALL..."`,
three spaces) also never matched the line written directly above it
(`"%sudo ALL..."`, one space), so it silently appended to the end of the file
rather than where it claimed. `verify.yml` runs `visudo -c` against the result.

## Hostname

Managed only when **not** on WSL. On WSL the hostname belongs to
`[network] hostname` in `wsl.conf` -- see the [wsl role](wsl.md) -- because the
`hostname` module's change does not survive a `wsl --shutdown`, which is why a
machine configured that way reverts to the Windows computer name.

`qemu-guest-agent` is installed only on a virtualised guest that is not WSL.
