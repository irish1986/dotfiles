# neovim

Neovim and its Lua configuration.

Installed from the upstream tarball rather than `ppa:neovim-ppa/unstable`, which
routinely has no pocket for a brand-new LTS. The previous role added that PPA and
*named that task* "Install packages" -- it never installed neovim.

`~/.config/nvim` is a symlink to this role's `files/` directory, so editing the
Lua tree in the repository takes effect immediately with no playbook run. It is
created as a symlink directly; the previous version created a real directory and
then overwrote it with a symlink using `force: true`, which masked the conflict
rather than avoiding it.

The Lua tree was renamed from `lua/techdufus/` to `lua/dotfiles/`, having carried
the upstream author's namespace since the fork.
