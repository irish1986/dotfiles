# Tools are list entries, not roles

Status: accepted, 2026-10-01

The `tools` role installs what the profiles list: apt packages, apt repositories, `.deb` releases, release binaries, installer scripts, uv tools, npm tools, gh extensions, agent skills (0008) and config files. Adding a tool is one entry in a profile; each entry that is not a plain apt package is checked with a `verify` command, `<name> --version` by default. uv and nvm are installer-script entries like any other; only node, which needs nvm's shell function rather than a download, is a plain task in the role. A tool that grows real configuration graduates to its own role.

Deleting an entry only stops managing the tool; uninstalling is done by hand. The removal lists that used to clean up after earlier versions are gone: a fresh distro never had those leftovers.
