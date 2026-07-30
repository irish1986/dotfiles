# docker

Docker Engine from the upstream apt repository.

This role is the reference implementation of the layout described in
[Role layout](../../docs/architecture/roles.md): it has an apt repository, a
template, a handler and an environment-conditional service, so it exercises every
part of the pattern.

## data-root

Left at Docker's default, `/var/lib/docker`, unless `docker_data_root` is set.

Relocating it into `$HOME` buys nothing on WSL -- `/home` and `/var` live in the
same `ext4.vhdx` -- and Docker requires the directory to be root-owned `0710`,
which is hostile to anything that walks the home directory. An earlier version
interpolated `ansible_user_dir`, which under the old global `become` resolved to
`/root`, so this machine's entire image store lived under `/root`.

If you do set it, migrate the existing store first or the images are orphaned.

## The service gate

Enabling and starting Docker is gated on `dotfiles_has_systemd`, not on "not
WSL". WSL2 with `systemd=true` in `wsl.conf` does have systemd and does want
Docker enabled; a CI container has none. The previous `not is_wsl` check expressed
neither, which is why Docker was installed but never enabled here.

`daemon.json` is written with `validate: dockerd --validate`, so a malformed
config fails the task instead of leaving Docker refusing to start with nothing in
the Ansible output to explain why.

Adding the user to the `docker` group takes effect on the next login session.
