# NixOS-WSL replaces the Ansible playbook

Status: accepted, 2026-11-19

Each machine moves from one Ubuntu WSL2 distro converged by Ansible (0001) to a NixOS-WSL distro built from a flake in this repo. The research behind this is in `specs/research/nixos-wsl.md`, and the steps are in `tasks/plan.md`.

## Structure

The flake has four inputs: `nixpkgs` on `nixos-unstable`, NixOS-WSL, home-manager and agenix, all following that one nixpkgs. Unstable rather than 26.05 because stable lags the CLIs this repo pins by many versions; `flake.lock`, the CI build and NixOS generations make a bad bump cheap to catch and roll back.

home-manager runs as a NixOS module, so there is one switch and one generation per change.

The profiles of 0002 become two outputs, `nixosConfigurations.personal` and `.work`, each importing a shared base module plus its own. Module merging does what the YAML layering did: lists concatenate, and `mkDefault`/`mkForce` set precedence.

The never-committed local file goes away, because a pure flake cannot read it:

- Non-sensitive values are committed in the host modules: hostname, Windows user name, personal git identity.
- Sensitive values are agenix secrets, read only at runtime: the `.env` variables (0010) and the work git identity, included by git from a decrypted file.

## Machine state without Ansible

Ansible's imperative steps become activation steps and a small wrapper, `scripts/switch`, which picks the profile from the hostname and runs `nixos-rebuild switch --flake`.

- **SSH (0006 stands):** activation copies the Windows key into `~/.ssh`, after users are created. The wrapper adds it to GitHub when `gh` is logged in.
- **agenix:** decrypts with the same Windows key, read directly from `/mnt/c` (`age.identityPaths`), so each machine's public key is a recipient. agenix runs before NixOS creates users, so on the first boot after a user rename the `~/.ssh` copy may not exist yet. Reading the Windows file avoids that ordering. The T1 spike showed `/mnt/c` is mounted during boot-time activation; the copy depends on `/mnt/c` too, so this adds no new dependency.
- **User services (0011 stands):** a home-manager activation step writes `~/.config/environment.d/999-wsl.conf`, with the same values and caveats as before. NixOS-WSL does not solve this.
- **Corporate CA (0007):** the CA stays on Windows. The work host reads `%USERPROFILE%\zscaler.cer`, exported as Base-64 PEM, into `security.pki.certificates`, so work rebuilds are `--impure`. The very first rebuild runs with `NIX_SSL_CERT_FILE` pointing at it. CI builds the work output with a dummy certificate behind the same option.

## Packages

nixpkgs comes first, replacing the apt, deb, binary and script lists of 0004. A tool nixpkgs lacks gets a small `fetchurl` derivation under `nix/pkgs/` with a Renovate comment. `programs.nix-ld` stays on for what can't be packaged: the VS Code Remote server, uv-managed Pythons and `npx` MCP servers. The agent CLIs come from nixpkgs too, allowed as unfree by name, so they no longer update themselves.

Agent config keeps 0008's split:

- Instruction files are links into the Nix store.
- MCP servers are merged by a jq step into each CLI's own writable config.
- Skills are fetched at pinned revs and linked into each agent's skills directory.

The zsh files move over unchanged first.

## Updates and CI

Renovate's `nix` manager bumps `flake.lock`, and the regex manager keeps the in-repo derivations and skill revs (0005). A lock-bump PR that fails CI is the upstream-rot signal.

CI is Linux only: the prek hooks, with nixfmt, statix and deadnix replacing ansible-lint, then `nix flake check` and a build of each profile's system. WSL behaviour (wsl.conf, interop, user services) is checked on the machines, not in CI. This replaces the container converge of 0009 and 0012.

## Migration

The work lives on a long-lived `nixos` branch where Ansible is deleted from the start, while `main` keeps the Ubuntu distros working. Renovate and the PR workflow cover both branches until the merge.

Each machine runs a `NixOS` distro (user `irish`) next to Ubuntu. Ubuntu is retired after two steps: the parity checklist in the tracking issue passes on both machines, then two weeks of daily use without opening Ubuntu. At that point Ubuntu is exported, `nixos` merges into `main`, and Ubuntu is unregistered. Home data is not copied wholesale: repos are re-cloned, and a short list of state is carried over.

## Rejected

- **Nix and home-manager on Ubuntu:** keeps prebuilt binaries working and the current CA setup, but leaves two package managers and an Ansible layer for the system.
- **Channels:** no lock file for Renovate or CI to work with.
- **sops-nix and a dedicated age key:** an extra key to place before the first rebuild.
- **`wsl.ssh-agent`:** reopens the broken-chain problem 0006 recorded.
- **A Windows-runner boot test in CI:** slow, and the WSL-specific checks stay manual.
- **Committing the CA:** it may be company-specific.

## Consequences

- On the branch this supersedes 0001, 0003, 0004 and 0009, and parts of 0002, 0005, 0007, 0010 and 0012. Each is marked superseded as its area is ported.
- **On work:**
  - Every rebuild is `--impure` and depends on the Windows CA export.
  - CI never builds the exact work system.
- **Binaries:** downloaded binaries need nix-ld or packaging, and anything installed outside Nix is not tracked by `flake.lock`.
- **Agent CLIs:** they lag upstream by however long nixpkgs-unstable takes, plus Renovate's buffer.
- **Untested until the T2 spike:** the `NIX_SSL_CERT_FILE` bootstrap. If it fails, this record changes. T1 confirmed the rest; see `specs/research/nixos-wsl.md` §20.
