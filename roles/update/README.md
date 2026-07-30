# update

System package upgrade and unattended-upgrades.

Runs **first** in `dotfiles_roles`, so everything below it installs against a
current package index.

## The lock it arms

This role enables `unattended-upgrades`, which then holds
`/var/lib/dpkg/lock-frontend` on a freshly booted machine. Run N therefore arms
the daemon that breaks run N+1's bare `apt-get` -- a recurring, self-inflicted
failure. Every apt call in `scripts/setup` now passes a lock timeout because of
this.

## Reboots

Gated on `dotfiles_can_reboot`, which is false on WSL and in containers.
`ansible.builtin.reboot` terminates a WSL distro and takes the playbook run with
it. Where a reboot is needed but not possible, the role reports it and continues.

The `apt.conf.d` fragments are templates rather than `blockinfile` edits, and
unattended-upgrades' own automatic reboot is disabled wherever a reboot is not
safe.
