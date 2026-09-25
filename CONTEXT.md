# Context

An Ansible playbook that provisions a Windows 11 + WSL2 Ubuntu workstation (and plain Ubuntu, which is how CI tests it), and the shell and tool configuration that goes with it. It is re-run whenever a tool is added or changed, so every run must be safe to repeat.

Decisions behind this shape are recorded in [`docs/adr/`](docs/adr/).

## Glossary

**Run** — one `ansible-playbook main.yml` execution, usually started by `scripts/setup`. A second run on an unchanged machine must report `changed=0`; CI asserts it.

**Bootstrap** — `scripts/setup`. Takes a bare Ubuntu to the point where a run can start (base packages, uv, ansible-core, the checkout, collections, the local file), then starts one.

**Profile** — a committed file under `profiles/` describing what a kind of machine gets. `base` applies to every machine; exactly one named profile (`home` or `work`) is layered on top of it.

**Local file** — `~/.config/dotfiles/local.yml`. Never committed. Holds what must not be public or differs per machine: `dotfiles_profile`, git identity, hostname, Windows user name, and network values such as the proxy and CA certificates.

**Layer** — one of base profile, named profile, local file, applied in that order. A later layer overrides scalars and dictionaries key by key and appends to lists. Avoid "override file" or "group_vars" for this; group_vars are not used for machine configuration.

**Full role** — a role under `roles/` with its own install, configure and verify phases. Reserved for things with real configuration: zsh, git, ssh, herdr, wsl, network, and the system-level roles (update, system, user).

**Tool entry** — one item in a `tools_*` list in a profile, installed by the `tools` role: an apt package, an apt repository, a `.deb`, a release binary, an installer script or a uv tool. Adding a tool means adding a tool entry, not a role. The `tools` role is the only thing that adds an apt repository; docker is one such entry, whose daemon configuration the `tools` role applies alongside it.

**Verify** — the last phase of every full role, and the `verify` command of a tool entry. It asserts that the thing installed actually works, so a run cannot quietly do nothing.

**Removal list** — `tools_remove_apt` and `tools_remove_paths`. Deleting a tool entry only stops managing it; uninstalling is explicit, by adding it here.

**Windows side** — files on the Windows host (`.wslconfig`, Windows Terminal settings, per-user fonts) that the `wsl` role manages through WSL interop, plus the SSH key that the `ssh` role manages. Every Windows-side task is skipped off WSL. It belongs to the Windows user, not to a distro, so on a host with several distros only the **global owner** writes it.

**Global owner** — the one distro, named by `wsl_global_owner` in every distro's local file, that writes the Windows side, except the SSH key, which any distro may create or rotate. The others only compare `.wslconfig` against their own settings and warn on drift. Unset, every distro writes it, which is only safe with a single distro.

**Machine key** — the one SSH key a machine has (ADR 0011). On WSL it is the Windows user's key, copied into every distro's `~/.ssh` on each run. Elsewhere it is the host's own `~/.ssh/id_ed25519`. Rotated with `scripts/setup --rotate-ssh-key`.
