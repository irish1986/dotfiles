# ggshield

[ggshield](https://github.com/GitGuardian/ggshield), the GitGuardian secret scanner, installed from the upstream GitHub release.

GitGuardian publishes a `.deb` per architecture on every release, so this is a real package rather than a loose binary -- the same arrangement as the [hugo](hugo.md) role, and the reason this role is much shorter than [snyk](snyk.md). dpkg owns the files, and `apt` verifies the archive.

## Not from PyPI

ggshield is also on PyPI, and this repository already has [uv](uv.md) installing Python tools with `uv tool install`.

The `.deb` wins anyway: a uv-managed ggshield lands in `~/.local/bin`, which `.zshrc` puts on `PATH` **ahead** of `/usr/bin`, so having both would leave two copies with the packaged one shadowed and only one of them ever updated. One installation method per tool.

## This is not the pre-commit hook

`.pre-commit-config.yaml` already runs ggshield as a hook, and [prek](prek.md) resolves that from its own pinned revision. The two are independent on purpose: the hook version is pinned per repository and updated by dependabot, while this role installs the CLI for interactive use -- `ggshield secret scan`, `ggshield auth login`.

Installing this role does not change what the hook runs.

## Version handling

`ggshield_version` is empty by default, which resolves the latest release through the GitHub API using `dotfiles_github_headers`.

The idempotence guard reads dpkg's record rather than `ggshield --version`, so it compares the same string apt would install -- including the Debian revision -- and a converged machine never re-fetches the archive.

`ggshield_deb_revision` exists because the revision is part of the asset filename (`ggshield_<version>-<revision>_<arch>.deb`) and of the version dpkg records. Upstream has never shipped anything but `1`.
