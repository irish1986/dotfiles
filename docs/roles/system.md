# system

Hostname, base packages and the guest agent.

Sudoers and the `~/.config` directory used to live here. Both moved to the [user role](user.md), which now owns everything about the login account -- this role is about the machine. The sudoers drop-in kept its path, `/etc/sudoers.d/90-dotfiles`, so an already-provisioned host reuses the same file.

## Hostname

Managed only when **not** on WSL. On WSL the hostname belongs to `[network] hostname` in `wsl.conf` -- see the [wsl role](wsl.md) -- because the `hostname` module's change does not survive a `wsl --shutdown`, which is why a machine configured that way reverts to the Windows computer name.

`qemu-guest-agent` is installed only on a virtualised guest that is not WSL.
