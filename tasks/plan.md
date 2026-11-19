# Plan: NixOS-WSL migration

## Overview

Both machines (personal and work) move from one Ubuntu WSL2 distro converged by Ansible to a NixOS-WSL distro built from a flake. The work happens on a long-lived `nixos` branch of this repo, where Ansible is deleted on day one; `main` keeps the Ubuntu distros working until cutover. NixOS runs side by side with Ubuntu; Ubuntu is retired once every item in the parity checklist works on both machines and they have had two weeks of daily use. Decisions are recorded in `specs/adr/0013-nixos-wsl-replaces-ansible.md`; background research is in `specs/research/nixos-wsl.md`.

Tasks are tracked in GitHub Issues: tracking issue [#287](https://github.com/irish1986/dotfiles/issues/287) holds the parity checklist, and each task is a sub-issue with native blocked-by links. The issues hold the live status. The task sections below are what the issues were created from.

## Architecture Decisions

Settled in the planning session on 2026-11-19 (full reasoning in ADR 0013):

- **Target:** NixOS-WSL. Ansible is dropped entirely; one-off machine setup moves to activation scripts and `scripts/switch`.
- **Flake:** flakes, with one `nixpkgs` input on `nixos-unstable`, plus `NixOS-WSL`, `home-manager` and `agenix` inputs following it.
- **home-manager:** runs as a NixOS module, so there is one switch and one generation.
- **Profiles:** `nixosConfigurations.personal` and `.work`, each importing `nix/modules/nixos/base.nix` plus a profile module.
- **No local file:**
  - Non-sensitive values (hostname, Windows user, personal git identity) are committed per host.
  - Sensitive values are agenix secrets read at runtime: the `.env` contents, and the work git identity through a git `[include]`.
- **SSH (ADR 0006 kept):** an activation step, run after `users`, copies `%USERPROFILE%\.ssh\id_ed25519{,.pub}` into `~/.ssh`.
- **Secrets:** agenix decrypts with the Windows key read directly from `/mnt/c` (`age.identityPaths`), not with the copy. agenix runs before `users`, so the copy may not exist yet (T1, variant A). Each machine's public key is a recipient.
- **Zscaler (work only):**
  - The first rebuild runs with `NIX_SSL_CERT_FILE`.
  - After that, `security.pki.certificates` reads `%USERPROFILE%\zscaler.cer`, exported as Base-64 PEM, so work rebuilds use `--impure`.
  - CI builds the work config with a dummy cert.
- **Packages:** nixpkgs first. Tools nixpkgs lacks get in-repo derivations under `nix/pkgs/`. nix-ld is on as a fallback, for VS Code Remote, uv-managed Pythons and npx.
- **Agent CLIs:** claude and copilot come from nixpkgs, with an `allowUnfree` predicate.
- **Agent config:**
  - Writable CLI configs get MCP entries merged in by a jq step at activation.
  - Instruction files are plain `home.file` links.
  - Skills are fetched with `fetchFromGitHub` at pinned revs and linked into each agent's skills folder.
- **Shell:** the existing zsh and p10k files are ported as-is through `home.file`. Moving to `programs.zsh` is deferred.
- **User services (ADR 0011 kept):** a home-manager activation step writes `~/.config/environment.d/999-wsl.conf`.
- **Docker:** `virtualisation.docker` runs natively.
- **Names:** user `irish` (renamed from `nixos` on first boot), distro `NixOS`, branch `nixos`.
- **Layout:** `flake.nix`, `flake.lock`, `nix/{hosts/{personal,work},modules/{nixos,home},pkgs}/` and `secrets/`.
- **Renovate:** the `nix` manager bumps `flake.lock`, and the regex manager bumps the in-repo derivations and skill revs. `baseBranches` includes `nixos`, and the lock-bump PRs act as the upstream-rot check.
- **CI:** Linux only: prek lint (adding nixfmt, statix, deadnix; removing ansible-lint), `nix flake check`, and a toplevel build per profile. It runs on PRs into `nixos`.
- **Rebuild:** `scripts/switch` in a local checkout. It picks the profile from the hostname and adds `--impure` on work.

## Task List

| Phase | Issues |
| --- | --- |
| 0: Branch | T0 #288 |
| 1: Spike | T1 #289, T2 #290 |
| 2: Foundation | T3 #291, T4 #292, T5 #293 |
| 3: Parity | T6 #294, T7 #295, T8 #296, T9 #297, T10 #298, T11 #299, T12 #300, T13 #301, T14 #302, T15 #303, T16 #304, T17 #305 |
| 4: Cutover | T18 #306, T19 #307, T20 #308 |

Each task is one PR into `nixos`, except T1 and T2, which are throwaway spikes. Labels follow `specs/agents/triage-labels.md`: `ready-for-human` where a person has to act on a Windows machine, `ready-for-agent` otherwise.

### Phase 0: Branch

#### T0: Open the `nixos` branch

**Description:** Create `nixos` from `main`. Add the ADR 0013 draft (as accepted), the research file and this plan. Docs only, no Nix yet.

**Acceptance criteria:**

- [ ] `nixos` exists on GitHub, and this task lands through a PR into it. Protection waits for T4, because `main`'s ruleset requires `CI OK`, which doesn't run on `nixos` yet.
- [ ] ADR 0013 is accepted and linked from `specs/CONTEXT.md`.

**Verification:** markdown lint passes (`prek run rumdl-check --all-files`).

**Dependencies:** none. **Files:** `specs/adr/0013-*.md`, `specs/research/nixos-wsl.md`, `tasks/plan.md`, `specs/CONTEXT.md`. **Scope:** S. **Label:** `ready-for-agent`.

### Phase 1: Risk spike (throwaway)

These run on a scratch distro (`wsl --install --from-file nixos.wsl --name NixOS-spike`), and nothing from them is merged except findings. T1 and T2 can run in parallel.

#### T1: Spike on personal

**Description:** Prove three assumptions with a minimal throwaway flake:

1. **Key copy before agenix:** an activation script that copies the Windows SSH key, ordered before agenix decryption (`system.activationScripts.agenixInstall.deps` or equivalent), decrypts a test secret on a fresh boot and on a rebuild.
2. **User services:** the `999-wsl.conf` approach gives a `systemd --user` service `WSL_DISTRO_NAME` and the Windows PATH, *while the Ubuntu distro is also running* (issue #888).
3. **VS Code:** `code .` opens VS Code Remote-WSL with `programs.nix-ld.enable`.

**Acceptance criteria:**

- [ ] Each of the three has a pass/fail result with the commands used.
- [ ] Each failure has a chosen fallback (e.g. dedicated age key; stop Ubuntu while testing).
- [ ] Results are appended as a "Spike results" section of `specs/research/nixos-wsl.md`.

**Verification:** manual, on the personal machine. **Dependencies:** T0. **Scope:** S (docs plus scratch config). **Label:** `ready-for-human`.

#### T2: Spike on work (Zscaler)

**Description:** On the work machine, install `NixOS-spike` from the stock `.wsl`. Export the CA as Base-64 PEM. Run the first `nixos-rebuild` with `NIX_SSL_CERT_FILE` pointing at a bundle built from it. Then switch to a config with `security.pki.certificates` read impurely from `/mnt/c`, and rebuild without the override. Also record whether `cache.nixos.org`, `github.com` and `channels.nixos.org` are reachable through Zscaler.

**Acceptance criteria:**

- [ ] The second rebuild succeeds without `NIX_SSL_CERT_FILE`.
- [ ] `curl https://cache.nixos.org` and `nix build nixpkgs#hello` work in a fresh shell.
- [ ] If the override fails, the fallback (a self-built image with the CA, per research §10) is written up.
- [ ] Findings are appended to the spike results.

**Verification:** manual, on the work machine. **Dependencies:** T0. **Scope:** S. **Label:** `ready-for-human`.

### Checkpoint A: spike review

- [ ] All four risks are resolved or have a fallback, and ADR 0013 is amended if a decision changed.
- [ ] Human review before Phase 2.

### Phase 2: Foundation

#### T3: Flake skeleton, Ansible removed

**Description:**

- Delete `roles/`, `profiles/`, `main.yml`, `ansible.cfg`, `inventory/`, `local.example.yml`, the Ansible `tests/` and `scripts/setup`.
- Add `flake.nix` with the four inputs, and `nix/hosts/{personal,work}/default.nix` setting `wsl.enable`, `wsl.defaultUser = "irish"`, `networking.hostName` and `system.stateVersion`.
- Add `nix/modules/nixos/base.nix`, enabling flakes, and home-manager wired in with an empty `nix/modules/home/base.nix`.
- Work host: a `dotfiles.corporateCa` option that defaults to a dummy test cert in `nix/tests/`.
- The base module carries the WSL fixes T1 found: `wsl.extraBin = [ { src = "${pkgs.coreutils}/bin/true"; } ]` (for WSL's generated `wsl-mnt-guard.service`) and `services.getty.enable = false` (otherwise `getty@tty1` fails and every switch exits with status 4).
- agenix's flake has no `home-manager` input any more, so only `agenix.inputs.nixpkgs.follows` is set.

**Acceptance criteria:**

- [ ] `nix flake check` passes.
- [ ] `nix build .#nixosConfigurations.{personal,work}.config.system.build.toplevel` both succeed on Linux.
- [ ] No Ansible file remains.

**Verification:** the two commands above. **Dependencies:** Checkpoint A. **Files:** `flake.nix`, `flake.lock`, `nix/hosts/*`, `nix/modules/{nixos,home}/base.nix`, deletions. **Scope:** M. **Label:** `ready-for-agent`.

#### T4: CI, lint and Renovate on the branch

**Description:**

- `pr.yml`: run on PRs into `nixos`, and replace the converge stage with `nix flake check` plus the two toplevel builds (using DeterminateSystems or cachix `install-nix-action`).
- `.pre-commit-config.yaml`: drop ansible-lint, add nixfmt, statix and deadnix as one hook family.
- `renovate.json`: add `nix` to `enabledManagers` and `nixos` to `baseBranches`, with the same 7-day buffer.
- `main.yml`'s one-liner install check doesn't apply on the branch; skip it there.

**Acceptance criteria:**

- [ ] A PR into `nixos` runs lint plus build, and `CI OK` aggregates them.
- [ ] `refs/heads/nixos` is added to the `main` ruleset's include list, so it gets the same protection: PRs, `CI OK`, signed commits, and no force-push or deletion.
- [ ] Renovate's dashboard lists a `flake.lock` update for `nixos`.

**Verification:** an open test PR. **Dependencies:** T3. **Files:** `.github/workflows/pr.yml`, `.github/workflows/main.yml`, `.pre-commit-config.yaml`, `renovate.json`. **Scope:** M. **Label:** `ready-for-agent`.

#### T5: `scripts/switch` and bootstrap

**Description:** Write `scripts/switch`, which:

- picks the profile from the hostname (or `--profile`);
- adds `--impure` on work;
- runs `sudo nixos-rebuild switch --flake .#<profile>`.

Update the README's install steps:

1. `wsl --install --from-file nixos.wsl --name NixOS`
2. the NixOS-WSL rename-user procedure to `irish`
3. clone the repo and check out `nixos`
4. run `scripts/switch`. The stock image has flakes off, so the first run passes `--option extra-experimental-features "nix-command flakes"`. On work, the first run also uses the `NIX_SSL_CERT_FILE` step from T2.

**Acceptance criteria:**

- [ ] The personal machine has a real `NixOS` distro built from the branch, running next to Ubuntu.
- [ ] Re-running `scripts/switch` is a no-op.

**Verification:** manual, on personal; shellcheck and shfmt pass. **Dependencies:** T3. **Files:** `scripts/switch`, `README.md`. **Scope:** S. **Label:** `ready-for-human` (the install itself).

### Checkpoint B: foundation

- [ ] CI is green on `nixos`, and the personal NixOS distro boots and rebuilds from the branch.

### Phase 3: Parity slices

Each task ticks its items in the parity checklist and marks the ADRs it supersedes as superseded.

#### T6: System basics

**Description:**

- `wsl.wslConf` covers today's wsl.conf template: interop, `appendWindowsPath`, automount and hostname.
- The `irish` user goes in the `wheel` and `docker` groups, with the sudo policy.
- Turn on `programs.nix-ld.enable`, Nix GC/optimise settings and `virtualisation.docker.enable`.
- Install `pkgs.wget`. Without it the VS Code server install fails, even with nix-ld (T1).

**Acceptance criteria:**

- [ ] `/etc/wsl.conf` matches the intent of `roles/system/templates/wsl.conf.j2`.
- [ ] `docker run --rm hello-world` works as `irish`.
- [ ] `code .` opens VS Code Remote.

**Dependencies:** Checkpoint B. **Files:** `nix/modules/nixos/{base,wsl,docker}.nix`. **Scope:** S. **Label:** `ready-for-agent`.

#### T7: Work profile and the Zscaler CA

**Description:**

- `nix/hosts/work`: `security.pki.certificates` from `builtins.readFile` of `/mnt/c/Users/<windows-user>/zscaler.cer`, only when not in CI.
- Set `SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS` and `REQUESTS_CA_BUNDLE` as today.
- Install the work machine's `NixOS` distro.

**Acceptance criteria:**

- [ ] Work rebuilds via `scripts/switch` with no manual override after the first.
- [ ] TLS works for curl, Nix, uv and npm.
- [ ] CI still builds `work` with the dummy cert.

**Dependencies:** T2, T5, T6. **Files:** `nix/hosts/work/default.nix`, `nix/modules/nixos/corporate-ca.nix`, `README.md`. **Scope:** S. **Label:** `ready-for-human`.

#### T8: SSH key copy

**Description:** A system activation step with `deps = [ "users" ]` copies both halves of the Windows key to `~irish/.ssh` (private 0600; a differing old copy is kept as a backup). On drvfs the key shows as mode 0777, which ssh refuses, so the copy is still needed. It fails clearly when Windows has no key. Uploading the key to GitHub (auth and signing) moves to `scripts/switch` as a post-switch step that runs only when `gh auth status` succeeds.

**Acceptance criteria:**

- [ ] A fresh distro has a working `ssh -T git@github.com`.
- [ ] A key replaced on Windows reaches the distro on the next switch.

**Dependencies:** Checkpoint B. **Files:** `nix/modules/nixos/ssh-key.nix`, `scripts/switch`. **Scope:** S. **Label:** `ready-for-agent`.

#### T9: agenix secrets

**Description:**

- `secrets/secrets.nix` lists both machines' `id_ed25519.pub` as recipients.
- `age.identityPaths = [ "/mnt/c/Users/<windows-user>/.ssh/id_ed25519" ]`. This reads the Windows key directly, so it doesn't depend on T8's copy; T1 showed it works on a cold boot.
- `secrets/env-personal.age` and `secrets/env-work.age` hold today's `.env` variables, decrypted to a 0600 file and exported by zsh.
- `secrets/git-identity-work.age` is a gitconfig fragment for the work identity.
- `.env.sample` stays as the reference for which variables exist.

**Acceptance criteria:**

- [ ] Every variable in `.env.sample` that is set today is available in a new shell on each machine.
- [ ] No plaintext secret is in git; the ggshield hook passes.
- [ ] Rotating a value is `agenix -e` plus a switch.

**Dependencies:** T1, Checkpoint B. **Files:** `secrets/*`, `nix/modules/nixos/secrets.nix`, `nix/modules/home/env.nix`. **Scope:** M. **Label:** `ready-for-human` (secret values).

#### T10: Shell: zsh, oh-my-zsh, p10k

**Description:**

- `programs.zsh.enable` at system level, with zsh as `irish`'s login shell.
- Port the files from `roles/zsh/files/` through `home.file` as-is.
- Pin oh-my-zsh, p10k and plugins from nixpkgs, or with `fetchFromGitHub` where today's pins differ.
- Source the decrypted env file from `.zshenv`.

**Acceptance criteria:**

- [ ] A new terminal looks and behaves like Ubuntu's: prompt, aliases and the WSL block with `pbcopy`/`open`/`winhome`.

**Dependencies:** T9. **Files:** `nix/modules/home/zsh.nix`, `nix/files/zsh/*`. **Scope:** M. **Label:** `ready-for-agent`.

#### T11: Git

**Description:** Move `programs.git` across from the git role: personal identity committed, work identity through `includes` pointing at the decrypted secret, and SSH signing with `id_ed25519.pub`. Create `~/git/<login>`.

**Acceptance criteria:**

- [ ] `git commit -S` produces a commit that GitHub shows as verified, on both machines, each with the right identity.

**Dependencies:** T8, T9. **Files:** `nix/modules/home/git.nix`, host files. **Scope:** S. **Label:** `ready-for-agent`.

### Checkpoint C: daily-driver shell

- [ ] Both machines run NixOS with a working shell, git, SSH, Docker, secrets and CA. Human review.

#### T12: User-service environment and herdr

**Description:**

- A home-manager activation step writes `~/.config/environment.d/999-wsl.conf` (ADR 0011 semantics: the distro name from `wslpath -w /`, and the Windows PATH from `cmd.exe` translated by `wslpath -u`, only while interop and `appendWindowsPath` are on).
- herdr comes from nixpkgs, with `systemd.user.services.herdr` and linger for `irish`.
- Deliberately no restart on switch.

**Acceptance criteria:**

- [ ] Inside a herdr pane, `code .`, `pbcopy` and `$WSL_DISTRO_NAME` work after a distro restart.
- [ ] herdr restores its session at boot.

**Dependencies:** T1, T10. **Files:** `nix/modules/home/{wsl-env,herdr}.nix`. **Scope:** M. **Label:** `ready-for-agent`.

#### T13: Packages from nixpkgs

**Description:** Translate `profiles/*.yml` tool lists to `home.packages` and `environment.systemPackages`:

- **base:** btop, gh plus the gh-aw and gh-stack extensions, fastfetch, grype, syft, hadolint, snyk, uv with Python 3.14, Node 26, prek, ggshield, zizmor
- **personal:** hugo, tailscale (`services.tailscale`)

Drop build-essential and the `-dev` libraries; use nix-ld or dev shells where they were needed. Any tool nixpkgs lacks moves to T14.

**Acceptance criteria:**

- [ ] Every tool in the parity checklist's tools section runs `--version` on its profile.

**Dependencies:** Checkpoint C. **Files:** `nix/modules/home/tools.nix`, `nix/hosts/personal/default.nix`. **Scope:** M. **Label:** `ready-for-agent`.

#### T14: In-repo derivations

**Description:** Write one `fetchurl` derivation per tool under `nix/pkgs/`, with `# renovate:` comments the regex manager understands, and add them to an overlay. win32yank is installed as `win32yank.exe` on PATH.

**Acceptance criteria:**

- [ ] `tokenuse --version` works.
- [ ] `pbcopy`/`pbpaste` round-trip through the Windows clipboard.
- [ ] Renovate detects each pin.

**Dependencies:** T13. **Files:** `nix/pkgs/{tokenuse,win32yank}/default.nix`, `nix/pkgs/default.nix`, `renovate.json`. **Scope:** S. **Label:** `ready-for-agent`.

#### T15: Agent CLIs, instructions and MCP

**Description:**

- copilot on both machines and claude on personal, from nixpkgs, with an `allowUnfreePredicate` limited to them.
- Link instruction files as today (`~/.copilot/copilot-instructions.md`, and `~/.claude/CLAUDE.md` on personal).
- A `home.activation` jq step merges each profile's MCP servers into each CLI's writable config, keeping other keys (ADR 0008).

**Acceptance criteria:**

- [ ] Both CLIs start, with self-update off.
- [ ] The MCP servers listed in each CLI match `profiles/personal.yml`.
- [ ] A setting saved from inside a CLI survives the next switch.

**Dependencies:** T13. **Files:** `nix/modules/home/agents.nix`, `nix/files/agents/instructions.md`. **Scope:** M. **Label:** `ready-for-agent`.

#### T16: Agent skills

**Description:** Fetch each skill source from today's `tools_agent_skills` with `fetchFromGitHub` at its pinned rev, with Renovate regex comments. Link the selected skills into each agent's global skills folder.

**Acceptance criteria:**

- [ ] Every skill installed on Ubuntu is listed by each agent on NixOS.
- [ ] A Renovate bump of one rev rebuilds and switches cleanly.

**Dependencies:** T15. **Files:** `nix/modules/home/skills.nix`, `renovate.json`. **Scope:** S. **Label:** `ready-for-agent`.

#### T17: Post-switch checks

**Description:** `scripts/switch` gets today's `tools_auth_checks` after the switch: for gh, copilot, ggshield and snyk, test that the variable is set and not a placeholder, then run the tool's status command. It warns, never fails, and is skipped in CI. It also prints the restart reminder when `999-wsl.conf` changed.

**Acceptance criteria:**

- [ ] A missing token prints one warning naming the tool, and the switch still exits 0.

**Dependencies:** T9, T15. **Files:** `scripts/switch`. **Scope:** S. **Label:** `ready-for-agent`.

### Checkpoint D: parity

- [ ] Every box in the parity checklist is ticked on both machines. Human review.

### Phase 4: Soak and cutover

#### T18: Move home data

**Description:** On each machine:

1. `wsl --export Ubuntu <backup>.tar`.
2. Re-clone repos into `~/git/<login>`.
3. Copy only the short list: zsh history, `~/.claude` sessions and project memory, `~/.copilot` session state, and any uncommitted work found by a `git status` sweep.

**Acceptance criteria:**

- [ ] A written list of what was copied.
- [ ] Ubuntu is no longer opened for daily work.

**Dependencies:** Checkpoint D. **Scope:** S. **Label:** `ready-for-human`.

#### T19: Two-week soak

**Description:** Daily use on both machines. Each fallback to Ubuntu, or each fix, becomes an issue and resets the clock for that machine.

**Acceptance criteria:**

- [ ] 14 consecutive days without opening Ubuntu, on both machines.

**Dependencies:** T18. **Label:** `ready-for-human`.

#### T20: Cutover

**Description:**

- Merge `nixos` into `main`, so Ansible disappears from `main`.
- Point CI and Renovate back at `main` only, and delete the branch.
- Mark the remaining superseded ADRs.
- On each machine, keep the export, then `wsl --unregister Ubuntu`.

**Acceptance criteria:**

- [ ] `main` builds both profiles.
- [ ] Renovate targets `main` only.
- [ ] Ubuntu is unregistered on both machines, with the backups kept somewhere you choose.

**Dependencies:** T19. **Files:** workflows, `renovate.json`, ADR statuses, `README.md`. **Scope:** M. **Label:** `ready-for-human`.

## Parallelization

- T1 and T2 run in parallel, on different machines.
- After Checkpoint B, T6, T8 and T13 are independent.
- T7 can run alongside T8 to T11.
- T14 and T15 are independent once T13 lands.

## Parity checklist (tracking issue body)

The cutover bar: every box ticked on both machines, then T19's two weeks.

- **System:**
  - [ ] wsl.conf (interop, appendWindowsPath, automount, hostname)
  - [ ] user `irish` with sudo
  - [ ] Docker
  - [ ] nix-ld and VS Code Remote
- **Work network:**
  - [ ] Zscaler CA trusted by Nix, curl, uv, npm and Python
  - [ ] package mirrors through `.env`
- **Identity:**
  - [ ] SSH key copied
  - [ ] key on GitHub (auth and signing)
  - [ ] git identity per profile
  - [ ] signed commits verified
- **Secrets:**
  - [ ] `.env` variables exported by every shell
  - [ ] auth checks warn correctly
- **Shell:**
  - [ ] zsh, oh-my-zsh, p10k and aliases
  - [ ] WSL block (`pbcopy`, `pbpaste`, `open`, `winhome`)
- **User services:**
  - [ ] `999-wsl.conf`
  - [ ] herdr unit and linger, restores at boot
- **Tools (base):**
  - [ ] btop, gh, gh-aw, gh-stack, fastfetch, grype, syft, hadolint, snyk, tokenuse
  - [ ] uv (Python 3.14), node 26, prek, ggshield, zizmor
- **Tools (personal):**
  - [ ] hugo, tailscale
- **Agents:**
  - [ ] copilot, and claude on personal
  - [ ] instructions
  - [ ] MCP servers (github, Snyk, terraform through Docker)
  - [ ] skills
- **Repo:**
  - [ ] CI green on `nixos`
  - [ ] Renovate bumping `flake.lock` and the regex pins
  - [ ] `scripts/switch` idempotent

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| The `NIX_SSL_CERT_FILE` first rebuild fails behind Zscaler | High (work blocked) | T2 runs first. Fallback: a self-built `.wsl` with the CA, built on personal. |
| `/mnt/c` isn't mounted when activation runs, so the key copy and agenix fail | Low | T1: `/mnt/c` and `cmd.exe` interop both worked during boot-time activation. Fallback: a dedicated age key in `/var/lib/agenix`, placed during bootstrap. |
| #888: the user session fails while Ubuntu runs alongside | Medium | T1 checks this. Fallback: `wsl --terminate Ubuntu` while using NixOS during the soak. |
| A nixpkgs-unstable bump breaks the build or a tool | Medium | A Renovate PR plus a CI build gate every bump; roll back to an earlier generation on the machine. |
| `--impure` work builds diverge from what CI builds (dummy cert) | Low | Only the CA differs, behind one option. |
| Renovate's `nix` manager is beta | Low | Fallback: a scheduled `update-flake-lock` workflow. |
| The long-lived branch drifts from `main` (Renovate pins, docs) | Low | The branch deletes Ansible, so main's tool bumps don't apply. Merge `main` into `nixos` only for shared files (`.github/`, `specs/`). |

## Open Questions

- Where should the `wsl --export` backups live after cutover (OneDrive, external disk, delete after N days)? This is needed by T20.
- ADR 0012 still describes `rot.yml`, but commit `f95021d` ("ci: update workflows") removed it. On `nixos`, Renovate's lock-bump PRs are the rot check. Should ADR 0012 be corrected on `main` now?
- ADR 0005 says a 3-day Renovate buffer, but `renovate.json` has 7 days. Which is right? This is unrelated drift found by the research.
