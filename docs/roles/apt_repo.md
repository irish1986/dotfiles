# apt_repo

Internal helper. Configures a third-party apt repository as a deb822 `.sources` file. Not user-selectable, and not listed in `dotfiles_roles` -- it is invoked with `include_role` by the roles that need it.

Five roles used to hand-roll "install deps, `apt_key`, `dpkg --print-architecture`, `apt_repository`", each slightly differently, and all five were broken or about to be: `apt-key` is gone in Ubuntu 24.04+ and the module is deprecated in ansible-core.

Built on `deb822_repository`, whose `signed_by:` accepts a URL and handles the fetch and dearmor itself -- so there is no `apt-key`, no `gpg` shellout and no `arch=...signed-by=...` string assembly.

## The suite probe

Third-party repositories routinely lag a new Ubuntu release, and pointing apt at a suite that 404s breaks `apt update` for *every* repository, not just the one at fault.

Rather than hardcode a codename map, the role sends a HEAD to the suite's `Release` file and falls back only when it is absent. A static map becomes a lie the moment the vendor catches up, and someone then has to notice and delete it; the probe self-heals on the next run. No Ubuntu codename is hardcoded anywhere in this repository.

Set `apt_repo_probe: false` for flat repositories, which have no `dists/` layout to probe.

`python3-debian` is installed here rather than by the caller, so the role is self-sufficient -- `deb822_repository` is built on it and it is absent from a minimal Ubuntu image.
