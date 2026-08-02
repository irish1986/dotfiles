# dotfiles

Ansible playbook that provisions a Windows 11 + WSL2 Ubuntu workstation, and the shell, editor and tooling configuration that goes with it.

It is a personal repository, published because the mechanics are reusable: a role layout that separates generic from OS-specific work, an apt-repository helper that survives new Ubuntu releases, and a bootstrap script that is safe to re-run.

## Goals

- **One command on a fresh machine.** `scripts/setup` takes a bare Ubuntu install to a working workstation, and is safe to run again afterwards.
- **Every supported Ubuntu LTS.** 22.04, 24.04 and 26.04, with no codename hardcoded anywhere.
- **WSL2 first.** The Windows side of the boundary is managed too: Terminal settings, fonts, clipboard, `wsl.conf` and `.wslconfig`.
- **Fail loudly.** Each role ends by asserting the thing it installs actually works, so a role cannot quietly do nothing.

## Quick start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/irish1986/dotfiles/main/scripts/setup)"
```

See [Getting started](getting-started/index.md) for what that does and what to set first.

## Where things are

| Section | Contents |
| --- | --- |
| [Getting started](getting-started/index.md) | Install, configure, secrets |
| [Roles](roles/index.md) | What each role does, generated from its source |
| [Reference](reference/index.md) | Variables, collections, CLI, playbook |
| [Architecture](architecture/index.md) | How the role layout and WSL boundary work |
| [Contributing](contributing/index.md) | Commit conventions and releases |
| [Troubleshooting](about/troubleshooting.md) | Things that go wrong |

## Credits

Heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles) and [TechDufus](https://github.com/TechDufus/dotfiles).
