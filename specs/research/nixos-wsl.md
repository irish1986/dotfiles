# Research: NixOS-WSL migration

Input for the planning session on moving this repo's target from one Ubuntu 26.04 WSL2 distro (ADR 0001) to NixOS-WSL. Researched 2026-11-19. Every claim links its source; "unverified" marks what could not be traced to a primary source. Line numbers refer to `nix-community/NixOS-WSL` `main` as read on 2026-11-19.

## Summary

- **NixOS-WSL is a set of NixOS modules plus a prebuilt rootfs**, not a fork of NixOS. You import `nixos-wsl.nixosModules.default`, set `wsl.enable = true`, and the module disables the kernel/boot loader, writes `/etc/wsl.conf` from Nix, and shims `/sbin/init` so NixOS activation runs before systemd ([flake.nix L26-35](https://github.com/nix-community/NixOS-WSL/blob/main/flake.nix#L26-L35), [design.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/design.md), [wsl-distro.nix L113-121](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L113-L121)).
- **Current versions:** latest release `2605.7.2` "Yearning Yarara" (2026-06-06), built on `nixos-26.05`; `main` tracks `nixos-unstable`. NixOS 26.11 is not branched yet in nixpkgs or home-manager as of 2026-11-19 ([releases](https://github.com/nix-community/NixOS-WSL/releases), [release-26.05 flake.nix](https://github.com/nix-community/NixOS-WSL/blob/release-26.05/flake.nix)).
- **Install** is `wsl --install --from-file nixos.wsl` (WSL >= 2.4.4) or `wsl --import` on older WSL; default user `nixos` with passwordless sudo; the image boots channel-based, so flakes are an opt-in you switch to ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md), [nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/nix-flakes.md)).
- **Biggest work-network risk: the Zscaler CA.** A stock image cannot reach `cache.nixos.org` through TLS inspection until the CA is trusted, and NixOS has no `update-ca-certificates`; maintainers' answer is to bake `security.pki.certificateFiles` into a custom-built image ([issue #918](https://github.com/nix-community/NixOS-WSL/issues/918), [building.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/building.md)). A one-off `NIX_SSL_CERT_FILE` bootstrap is plausible but untested here (section 10).
- **Prebuilt/foreign binaries do not run by default** (no `/lib64/ld-linux-x86-64.so.2`): VS Code Remote server, `curl | sh` installers (Claude Code, Copilot CLI, nvm, uv's managed Pythons), npm/pip wheels with native binaries. Fixes: `programs.nix-ld.enable`, or take the tool from nixpkgs ([vscode.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/vscode.md), [nixpkgs uv doc](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/doc/packages/uv.section.md)). Almost every tool in `profiles/*.yml` is already in nixpkgs-unstable, often at the exact pinned version (section 7).
- **ADR 0011's problem does not go away.** systemd user services under WSL still don't get the WSL session environment; NixOS-WSL wraps login shells to load `/etc/set-environment`, but user units are a known pain point ([#375](https://github.com/nix-community/NixOS-WSL/issues/375), [#888](https://github.com/nix-community/NixOS-WSL/issues/888), [#1074](https://github.com/nix-community/NixOS-WSL/issues/1074), [#171](https://github.com/nix-community/NixOS-WSL/issues/171)).
- **ADR 0006 has a first-class alternative:** `wsl.ssh-agent.enable` (new in 2605.7.x) runs `wsl2-ssh-agent` as a user service bridging to the Windows OpenSSH agent ([ssh-agent.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/ssh-agent.nix)). Copying the key also still works.
- **Renovate's `nix` manager exists but is beta and off by default**: it updates `flake.lock` inputs (git-refs only) and runs lock-file maintenance through the `nix` binary ([manager source](https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/nix/index.ts), [docs](https://docs.renovatebot.com/modules/manager/nix/)). It does not replace the per-tool `# renovate:` comments; with Nix, nixpkgs owns most versions.
- **CI can test more than today:** `nix flake check` / building `system.build.toplevel` on Ubuntu runners, and NixOS-WSL's own CI builds the `.wsl` image and boots it under real WSL on `windows-latest` with Pester tests, which today's container CI can't do (ADR 0009) ([run_tests.yml](https://github.com/nix-community/NixOS-WSL/blob/main/.github/workflows/run_tests.yml)).
- **Honest alternative:** keep Ubuntu, add multi-user Nix + standalone home-manager for user-level tools/dotfiles. It keeps FHS compatibility (no nix-ld), apt, and the current CA/bootstrap story, at the cost of two package managers and no declarative system layer (section 1).

## 1. NixOS-WSL vs Nix on Ubuntu

| | NixOS-WSL | Nix + home-manager on Ubuntu 26.04 |
| --- | --- | --- |
| What it is | NixOS with WSL modules; whole system declared in Nix ([README](https://github.com/nix-community/NixOS-WSL/blob/main/README.md)) | Nix package manager installed into Ubuntu; HM manages `$HOME` ([HM standalone](https://nix-community.github.io/home-manager/installation/standalone.html)) |
| System layer (`/etc`, services, CA store, `wsl.conf`, users, docker) | Nix options (`wsl.*`, `security.pki.*`, `virtualisation.docker.*`) | Still apt/Ansible, or [numtide/system-manager](https://github.com/numtide/system-manager) (v1.1.0, 2026-03-12; manages system config with Nix "on any distro") |
| Prebuilt binaries | Need nix-ld or nixpkgs builds ([nix-ld](https://github.com/Mic92/nix-ld)) | Work as today (FHS present); nix-ld "doesn't work on non-NixOS" and isn't needed ([nix-ld README](https://github.com/Mic92/nix-ld)) |
| Install | `.wsl` image ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)) | `curl -L https://nixos.org/nix/install \| sh -s -- --daemon`; multi-user needs systemd, which WSL >= 0.67.6 supports ([nixos.org/download](https://nixos.org/download/)) |
| Rollback | System generations (`nixos-rebuild switch --rollback`) ([man page](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd)) | HM generations only; apt changes are not rolled back |
| Convergence | Build is pure; activation replaces the system atomically | Two worlds to keep converged |
| Tool sources | nixpkgs (stable or unstable), overlays, flake inputs | nixpkgs for user tools, apt for the rest |

Nix's official manual recommends the multi-user (daemon) install on Linux with systemd ([Nix 2.34 manual, installation](https://nix.dev/manual/nix/stable/installation/)). nixos.org lists Nix 2.35.6 and NixOS 26.05 as current ([download page](https://nixos.org/download/)).

## 2. Versions and release cadence

| Item | Value (2026-11-19) | Source |
| --- | --- | --- |
| Latest NixOS-WSL release | `2605.7.2`, 2026-06-06; assets `nixos.wsl`, `nixos.aarch64.wsl` (+ `.sha256`) | [release](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2) |
| Previous | `2511.7.1` (2026-03-01), `2505.7.0`, `2411.6.0` | [releases](https://github.com/nix-community/NixOS-WSL/releases) |
| Version scheme | `YYMM.x.y`; release branch `release-26.05` pins `nixpkgs` to `nixos-26.05`; `main` pins `nixos-unstable` | [release-26.05 flake.nix](https://github.com/nix-community/NixOS-WSL/blob/release-26.05/flake.nix), [main flake.nix L5](https://github.com/nix-community/NixOS-WSL/blob/main/flake.nix#L5) |
| Repo activity | last push 2026-11-17; 52 open issues; last feature commit #1120 (2026-11-10, trust default user in nix-daemon, on `main` only) | `gh api repos/nix-community/NixOS-WSL` |
| NixOS stable | 26.05 (`nixos-26.05` updated 2026-11-16); `nixos-26.11` branch does not exist yet | `gh api repos/NixOS/nixpkgs/branches/...` |
| home-manager | `release-26.05` and `master`; no `release-26.11` yet | `gh api repos/nix-community/home-manager/branches/...` |
| WSL (Windows side) | 3.0.5 latest GitHub release (2026-11-03) | [microsoft/WSL releases](https://github.com/microsoft/WSL/releases) |
| Nix | manual 2.34.9; nixos.org installer 2.35.6 | [conf-file](https://nix.dev/manual/nix/stable/command-ref/conf-file.html), [download](https://nixos.org/download/) |

The 2605 release notes upgrade path is channel-based: `nix-channel --add https://nixos.org/channels/nixos-26.05 nixos` plus the matching `NixOS-WSL/archive/refs/heads/release-26.05.tar.gz nixos-wsl` channel, then `nix-channel --update` and `nixos-rebuild switch` ([release notes](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2)). With flakes this becomes bumping the two inputs. When NixOS 26.11 ships, expect a `release-26.11` branch and a `2611.*` release (pattern-based, unverified).

## 3. Installation and first boot

1. Requirements: "tested with the Windows Store version of WSL 2", on Windows 10 and 11; inbox WSL is best-effort ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)). The `.wsl` format needs WSL >= 2.4.4 ([MS: build custom distro](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)).
2. `wsl --install --no-distribution` if WSL is absent ([README](https://github.com/nix-community/NixOS-WSL/blob/main/README.md)).
3. Download `nixos.wsl` from the release (named `nixos-wsl.tar.gz` before 2411) and run `wsl --install --from-file nixos.wsl [--name X] [--location Y]`, or double-click it. Default distro name `NixOS`; default disk location `%localappdata%\wsl\{GUID}` ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)). The name comes from `oobe.defaultName = "NixOS"` in the image's `/etc/wsl-distribution.conf` ([build-tarball.nix L9-14](https://github.com/nix-community/NixOS-WSL/blob/main/modules/build-tarball.nix#L9-L14)).
4. Older WSL: `wsl --import NixOS $env:USERPROFILE\NixOS nixos.wsl --version 2` ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)).
5. First shell: user `nixos`, in `wheel`, uid 1000 (`mkDefault`), passwordless sudo: the module sets `security.sudo.wheelNeedsPassword = mkDefault false` ([wsl-distro.nix L175-191](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L175-L191)). Note: install.md says the NixOS default is `true` and to set a password "in case" you enable it; the module overrides the default to `false`. Not a contradiction, but easy to misread.
6. `sudo nix-channel --update` once before the first `nixos-rebuild` ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)). The image pre-seeds root's channels to its own nixpkgs and NixOS-WSL source ([flake.nix L55-66](https://github.com/nix-community/NixOS-WSL/blob/main/flake.nix#L55-L66)), and ships `/etc/nixos/configuration.nix` importing `<nixos-wsl/modules>` with `wsl.enable`, `wsl.defaultUser` and `system.stateVersion` ([build-tarball.nix L27-53](https://github.com/nix-community/NixOS-WSL/blob/main/modules/build-tarball.nix#L27-L53)).
7. `wsl -s NixOS` to make it the default distro ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)).

**Changing the username** (`nixos` to yours): set `wsl.defaultUser`, run `sudo nixos-rebuild boot` (not `switch`: "may lead to the new user account being misconfigured"), `wsl -t NixOS`, `wsl -d NixOS --user root exit`, `wsl -t NixOS`, reopen ([change-username.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/change-username.md)). In a self-built image, setting `wsl.defaultUser` before building is enough (same page). The `[user] default` in `wsl.conf` follows `users.users.<defaultUser>.name` automatically ([systemd/native/default.nix L24](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/native/default.nix#L24)).

**Building your own image** (relevant for the CA and for skipping first-boot setup): `sudo nix run github:nix-community/NixOS-WSL#nixosConfigurations.default.config.system.build.tarballBuilder`, or `.#nixosConfigurations.<host>.config.system.build.tarballBuilder` from your own flake; supports `--extra-files <dir>` and `--chown <path> <uid:gid>`; output `nixos.wsl` ([building.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/building.md)). Requires a machine (or CI runner) that already has Nix.

**Recovery:** `wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery [--system /nix/var/nix/profiles/system-42-link]` activates and chroots from WSL's system distro, optionally into an older generation ([recovery-shell.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/troubleshooting/recovery-shell.md)).

Docs site pages that exist: Installation, Design, Building, How-to (VSCode Remote, change username, flakes), Troubleshooting (general, recovery shell), Options ([SUMMARY.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/SUMMARY.md)). There are no dedicated Docker, systemd or nix-ld pages; those are covered by module source and options.

## 4. Config layout: flakes, HM

### Channels vs flakes

- The shipped image is channel-based (`<nixos-wsl/modules>`). The default config built from the flake sets `nixpkgs.flake.source = mkForce null` because "Per default the resulting systems aren't flake-enabled" ([flake.nix L50-53](https://github.com/nix-community/NixOS-WSL/blob/main/flake.nix#L50-L53)).
- Flakes are still experimental in Nix (`experimental-features` default is empty) and must be enabled, e.g. `nix.settings.experimental-features = [ "nix-command" "flakes" ];` ([Nix conf-file](https://nix.dev/manual/nix/stable/command-ref/conf-file.html)). The NixOS-WSL flakes page gives only a minimal `flake.nix` (inputs `nixpkgs` + `nixos-wsl`, module `nixos-wsl.nixosModules.default`, `wsl.enable = true`) ([nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/nix-flakes.md)); issue [#604](https://github.com/nix-community/NixOS-WSL/issues/604) (open) calls those docs unclear.
- Where config lives: `nixos-rebuild` uses `/etc/nixos/flake.nix` as if `--flake` were passed, and "This file may be a symlink to a flake.nix in an actual flake; thus /etc/nixos need not be a flake"; the flake attribute defaults to the hostname ([nixos-rebuild(8)](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd)). So the repo can stay at `~/.dotfiles` and be applied with `sudo nixos-rebuild switch --flake ~/.dotfiles#<host>`, as frankper does (`--flake .#wsl`) ([frankper guide](https://frankper.gitlab.io/the-one-nix/guides/manage-nixos-in-wsl/)).
- Flakes only see git-tracked files; a never-committed local file (ADR 0002 layer 3) cannot be read by a pure flake evaluation. Options: pass it as a separate flake input overridden per machine (dmadisetti's `sensitive.url = "path:./nix/spoof"` template, [flake.nix](https://github.com/dmadisetti/.dots/blob/template/flake.nix), [spoof/flake.nix](https://github.com/dmadisetti/.dots/blob/template/nix/spoof/flake.nix)), evaluate with `--impure`, or keep identity in a private repo/secret. (The git-tracked rule is general Nix flakes behavior; not re-verified in a primary doc for this report.)

### Home Manager: module vs standalone

| | HM as NixOS module | HM standalone |
| --- | --- | --- |
| Applied by | `nixos-rebuild switch` (one command, one lock) | `home-manager switch` as the user |
| Activation | `home-manager-$USER.service` system unit at boot and rebuild, or the user's `home-manager.service` with `home-manager.startAsUserService` ([HM: NixOS module](https://nix-community.github.io/home-manager/installation/nixos.html)) | user runs it |
| Packages | `useGlobalPkgs = true` reuses system `pkgs` ("saves an extra Nixpkgs evaluation"); `useUserPackages = true` installs to `/etc/profiles` ([HM: NixOS module](https://nix-community.github.io/home-manager/installation/nixos.html)) | own nixpkgs instance |
| Works on Ubuntu too | no | yes; branch must match nixpkgs (`release-26.05` with 26.05, `master` with unstable) ([HM standalone](https://nix-community.github.io/home-manager/installation/standalone.html)) |
| Flake wiring | `home-manager.nixosModules.home-manager`, `home-manager.users.<name> = ./home.nix`, `extraSpecialArgs` for inputs ([HM: flakes + NixOS](https://nix-community.github.io/home-manager/nix-flakes/nixos.html)) | `homeConfigurations.<name>` |

dmadisetti's repo builds both from the same modules: `mkComputer` (HM as NixOS module, `useGlobalPkgs`/`useUserPackages`) and `mkHome` (standalone `homeManagerConfiguration`) ([utils.nix](https://github.com/dmadisetti/.dots/blob/template/nix/utils.nix)). That shape keeps the "Nix on Ubuntu" path open.

HM file semantics that matter for ADR 0008 (merging MCP servers into configs the CLIs also write): `home.file` sources are "copied or linked through the Nix store"; collisions abort activation unless `backupFileExtension`/`-b` or `force = true`; `config.lib.file.mkOutOfStoreSymlink` links to a live mutable path ([HM: dotfiles](https://nix-community.github.io/home-manager/usage/dotfiles.html)). Store files are immutable, so a CLI that rewrites its own config file (e.g. adding MCP servers or auth state) will clash with a store-linked file; merging into a mutable file needs an activation script (`home.activation`) instead. HM ships modules for `programs.claude-code` (settings, context, skills, `mcpServers`), `programs.mcp`, `programs.zsh` (with `oh-my-zsh`), `programs.git`, `programs.ssh`, `programs.gh`, `programs.btop`, `programs.fastfetch`, `programs.uv`, `services.ssh-agent` on `release-26.05` ([HM modules tree](https://github.com/nix-community/home-manager/tree/release-26.05/modules/programs)); there is no `programs.herdr` module.

## 5. `wsl.*` options

From the [options reference](https://nix-community.github.io/NixOS-WSL/options.html) and module source (`main`):

| Option | Default | Notes |
| --- | --- | --- |
| `wsl.enable` | `false` | Turns on everything below ([wsl-distro.nix L44](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L44)) |
| `wsl.defaultUser` | `"nixos"` | Created as normal user, uid 1000, `wheel` ([L71-75](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L71-L75), [L175-179](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L175-L179)) |
| `wsl.startMenuLaunchers` | `false` | Copies `share/applications` and icons (system, `/etc/profiles/per-user`, `~/.nix-profile`) into `/usr/share` for WSLg Start-menu entries ([L110](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L110), [L194-218](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L194-L218)); [#1116](https://github.com/nix-community/NixOS-WSL/issues/1116) open |
| `wsl.useWindowsDriver` | `false` | Symlinks `/usr/lib/wsl/lib` GPU libs into `hardware.graphics.extraPackages` ([L45](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L45), [L126-130](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L126-L130)) |
| `wsl.wslLibExtraLinks`, `wsl.wslLib` | `[]` / generated | Extra GPU lib links |
| `wsl.extraBin` | sh, bash, mount, true, wslpath, login, recovery | Files linked into `/bin` for WSL's own tooling ([L235-241](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L235-L241)) |
| `wsl.wrapBinSh` | `true` | Wraps `/bin/sh` so non-login shells get the NixOS environment ([wrap-shell.nix L30](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/native/wrap-shell.nix#L30)) |
| `wsl.wslConf` | `{}` (freeform INI) | Rendered to `/etc/wsl.conf`; any key from [MS wsl.conf](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) is accepted ([wsl-conf.nix L9-23, L120-122](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L9-L23)) |
| `wsl.wslConf.automount.enabled` / `.root` / `.options` / `.mountFsTab` / `.ldconfig` | `true` / `"/mnt"` / `"metadata,uid=1000,gid=100"` / `false` / `false` | `mountFsTab` false because "systemd will mount those for you" ([wsl-conf.nix L25-53](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L25-L53)) |
| `wsl.wslConf.boot.systemd` | `true` (forced on) | Warning if disabled: "WILL break things" ([L61-65](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L61-L65), [L124-125](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L124-L125)) |
| `wsl.wslConf.boot.command` / `.initTimeout` | `""` / `null` (WSL default 10000 ms) | `initTimeout` relevant to [#888](https://github.com/nix-community/NixOS-WSL/issues/888) ([L56-75](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L56-L75)) |
| `wsl.wslConf.interop.enabled` / `.appendWindowsPath` | `true` / `true` | ([L77-88](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L77-L88)) |
| `wsl.wslConf.network.generateHosts` / `.generateResolvConf` / `.hostname` | `true` / `true` / `config.networking.hostName` | When WSL generates them, NixOS stops managing `/etc/hosts`, `/etc/resolv.conf` and resolvconf; warnings if `services.resolved` or `networking.nameservers` conflict ([wsl-conf.nix L89-105](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L89-L105), [wsl-distro.nix L134-141, L173, L258-268](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L258-L268)) |
| `wsl.wslConf.user.default` | `"root"` in the option, set to `defaultUser` by the systemd module | ([systemd/native/default.nix L24](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/native/default.nix#L24)) |
| `wsl.interop.includePath` | `true` | Keeps Windows entries in `PATH`; NixOS-WSL splits `PATH` into native and `WSLPATH` at shell init ([interop.nix L12-16](https://github.com/nix-community/NixOS-WSL/blob/main/modules/interop.nix#L12-L16), [native/default.nix L62-65](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/native/default.nix#L62-L65)) |
| `wsl.interop.register` | `false` | Re-register the `WSLInterop` binfmt handler; needed if you add any `boot.binfmt` registrations ([interop.nix L6-10, L35-39](https://github.com/nix-community/NixOS-WSL/blob/main/modules/interop.nix#L35-L39)) |
| `wsl.docker-desktop.enable` | `false` | Adds `xdg-utils`, `/bin` helpers Docker Desktop's integration expects, and puts `defaultUser` in `docker` ([docker-desktop.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/docker-desktop.nix)) |
| `wsl.ssh-agent.enable` / `.package` / `.users` | `false` / `pkgs.wsl2-ssh-agent` / `"!@system"` | User service `wsl2-ssh-agent`, sets `SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/wsl2-ssh-agent.sock` ([ssh-agent.nix L12-54](https://github.com/nix-community/NixOS-WSL/blob/main/modules/ssh-agent.nix#L12-L54)); added in 2605 ([#898](https://github.com/nix-community/NixOS-WSL/pull/898)) |
| `wsl.usbip.enable` / `.autoAttach` / `.snippetIpAddress` | `false` / `[]` / gateway from `ip route` | Enables udev, `usbip-auto-attach@` units ([usbip.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/usbip.nix)); [#1069](https://github.com/nix-community/NixOS-WSL/issues/1069) says autoAttach broken |
| `wsl.tarball.configPath` | `null` | Config copied into a built image |

Removed/renamed options to recognise in old guides: `wsl.nativeSystemd` (removed: "Native systemd is now always enabled as support for syschdemd has been removed"), `wsl.docker-native` (removed: use `virtualisation.docker`), `wsl.interop.preserveArgvZero`, `wsl.tarball.includeConfig`, `wsl.docker` renamed to `wsl.docker-desktop`, `wsl.automountPath`/`automountOptions` renamed under `wslConf.automount` ([systemd/default.nix L7](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/default.nix#L7), [modules/default.nix L15-21](https://github.com/nix-community/NixOS-WSL/blob/main/modules/default.nix#L15-L21), [docker-desktop.nix L5](https://github.com/nix-community/NixOS-WSL/blob/main/modules/docker-desktop.nix#L5), [wsl-conf.nix L5-6](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L5-L6)).

Other defaults the module forces: no initrd/kernel/grub, `console.enable = false`, `networking.dhcpcd.enable = false`, `powerManagement.enable = false`, `services.timesyncd.enable = false` (WSL's chronyd), `services.udev.enable = mkDefault false`, `systemd.oomd.enable = mkDefault false`, firewall unit disabled, no emergency mode, `nix.settings.trusted-users` += defaultUser when sudo is passwordless (main only, #1120) ([wsl-distro.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix), [systemd/default.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/default.nix)).

Mapping today's `roles/system/templates/wsl.conf.j2`: `systemd`, `automount.*`, `interop.*`, `network.hostname/generateHosts/generateResolvConf`, `user.default` all have typed `wsl.wslConf.*` options. Two default differences: NixOS-WSL uses `mountFsTab = false` (today `true`) and `options = "metadata,uid=1000,gid=100"` (today `metadata,umask=22,fmask=11`); `gid=100` is the NixOS `users` group. The `fmask=11` rationale (owner execute bit for `.exe` files) carries over unchanged.

## 6. systemd and user services

- NixOS-WSL uses WSL's native systemd only. `/sbin/init` is a shim that runs `/nix/var/nix/profiles/system/activate` and then execs systemd ([native/default.nix L54-57](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/native/default.nix#L54-L57), [utils/src/shim.rs](https://github.com/nix-community/NixOS-WSL/blob/main/utils/src/shim.rs)).
- Login shells started by `wsl.exe` are wrapped (`shell-wrapper`): the wrapper waits for activation, then loads `/etc/set-environment` unless already done, skipping WSL's own SIGCHLD-ignored session shell ([shell_wrapper.rs](https://github.com/nix-community/NixOS-WSL/blob/main/utils/src/shell_wrapper.rs), [wrap-shell.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/native/wrap-shell.nix)). Upstream cause: [microsoft/WSL#9213](https://github.com/microsoft/WSL/issues/9213), tracked in [#171](https://github.com/nix-community/NixOS-WSL/issues/171) (open since 2022).
- `environment.variables.PATH = [ "$PATH" ]` preserves the WSL-provided PATH; `environment.sessionVariables.PATH` breaks rebuilds unless `mkForce` with `"$PATH"` included ([native/default.nix L62](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/native/default.nix#L62), [#472](https://github.com/nix-community/NixOS-WSL/issues/472)).
- `systemctl --user` failures: "Failed to connect to bus" ([#375](https://github.com/nix-community/NixOS-WSL/issues/375), maintainer: a WSL bug, same on Ubuntu); "Failed to start the systemd user session" when another distro is already running ([#888](https://github.com/nix-community/NixOS-WSL/issues/888), reproduced on Ubuntu 26.04 + Rocky, maintainer: "clearly an upstream issue"); slow units (Docker, HM activation) can exceed WSL's 10 s init timeout (comment in #888), which `wsl.wslConf.boot.initTimeout` can raise; `nixos-rebuild switch` errors activating user units in headless WSL (`guiApplications=false`), worked around with `nixos-rebuild boot` + restart ([#1074](https://github.com/nix-community/NixOS-WSL/issues/1074)). NixOS-WSL's CI has a Pester test that `systemctl --user status` succeeds after a 10 s wait ([systemd-user.Tests.ps1](https://github.com/nix-community/NixOS-WSL/blob/main/tests/systemd-user.Tests.ps1)).
- **ADR 0011 mapping.** The same gap (user units lack `WSL_DISTRO_NAME` and the Windows PATH) applies; NixOS-WSL's fixes target login shells, not the user manager. Declarative equivalents of `~/.config/environment.d/999-wsl.conf`: HM `systemd.user.sessionVariables` writes `~/.config/environment.d/10-home-manager.conf` ([HM systemd.nix L231-233](https://github.com/nix-community/home-manager/blob/release-26.05/modules/systemd.nix#L231-L233)); NixOS `systemd.user.extraConfig` can set `DefaultEnvironment=` ([user.nix L70](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/system/boot/systemd/user.nix#L70)). The Windows PATH is machine state, not known at build time, so it still needs a runtime step (activation script or user oneshot calling `cmd.exe` by full path; interop works via binfmt, per ADR 0011). That design is unverified on NixOS-WSL. herdr is packaged in nixpkgs (0.9.5) but has no HM module; its unit would be a hand-written `systemd.user.services.herdr`.
- MS recommends masking `systemd-resolved`, `systemd-networkd`, `NetworkManager`, `systemd-tmpfiles-*`, `tmp.mount` in WSL distros ([MS: build custom distro](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)); NixOS-WSL warns on `services.resolved` with WSL-managed resolv.conf but does not mask tmpfiles (it uses tmpfiles itself, [flake.nix L55-66](https://github.com/nix-community/NixOS-WSL/blob/main/flake.nix#L55-L66)).

## 7. Foreign and prebuilt binaries

- NixOS lacks `/lib64/ld-linux-x86-64.so.2`; the VS Code Remote server downloads a Node binary that needs it. Option 1 `programs.nix-ld.enable = true` ("more robust but might impact other programs"); option 2 K900's `vscode-remote-workaround` module patching in nixpkgs Node; both need `wget` installed ([vscode.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/vscode.md)).
- nix-ld installs a shim loader at the standard path that execs the loader in `NIX_LD` with `NIX_LD_LIBRARY_PATH`; NixOS module `programs.nix-ld.{enable,package,libraries}` with a default library set (zlib, zstd, stdenv.cc.cc, curl, openssl, attr, ...) ([nix-ld.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/programs/nix-ld.nix), [nix-ld README](https://github.com/Mic92/nix-ld)). Limits: libraries must be listed by hand; nixpkgs interpreters ignore the variables ([nix-ld README](https://github.com/Mic92/nix-ld)).
- uv: by default fetches dynamically linked Pythons that fail on NixOS. nixpkgs recommends `UV_PYTHON` pointing at a nixpkgs Python plus `UV_PYTHON_DOWNLOADS=never`, with nix-ld as the "works on my machine" fallback; PyPI wheels vendoring native libs (numpy) need `LD_LIBRARY_PATH` ([nixpkgs doc/packages/uv.section.md](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/doc/packages/uv.section.md)). The same applies to npm packages that download native binaries (`npx -y snyk@latest mcp` in the profiles): with nix-ld they likely work, without it they likely fail (inference, unverified).
- `services.envfs` (populate `/bin`, `/usr/bin` for `#!/bin/bash`-style shebangs) is supported (NixOS-WSL disables `populateBin` for it, [wsl-distro.nix L234](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix#L234), [tests/envfs](https://github.com/nix-community/NixOS-WSL/blob/main/tests/envfs/envfs.nix)) but has caused "Failed to mount C:\" at boot ([#846](https://github.com/nix-community/NixOS-WSL/issues/846), [#1112](https://github.com/nix-community/NixOS-WSL/issues/1112) open).

### Today's tools in nixpkgs

Checked `pkgs/by-name` on `nixos-unstable` on 2026-11-19 (`gh api repos/NixOS/nixpkgs/contents/...`). "Pin" is the version in `profiles/*.yml` / role defaults.

| Tool (current install kind) | nixpkgs-unstable | Pin today | Note |
| --- | --- | --- | --- |
| gh (apt repo) | 2.104.0 | apt latest | |
| docker (apt repo) | NixOS module | apt latest | section 8 |
| fastfetch, grype, syft (`.deb`) | present / 0.121.3 / 1.56.0 | 2.71.0 / 0.121.3 / 1.57.1 | syft one minor behind |
| hadolint, snyk, tokenuse (binaries) | haskellPackages `hadolint` / 1.1308.4 / absent | 2.15.1 / 1.1308.4 / 1.2.8 | tokenuse needs own derivation or nix-ld |
| copilot (install.sh) | `github-copilot-cli` 1.0.108 (26.05: 1.0.61) | 1.0.108 | |
| claude (install.sh, unpinned) | `claude-code` 2.1.325, wrapped with `DISABLE_AUTOUPDATER=1` ([package.nix L56-60](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/cl/claude-code/package.nix)) | self-updating | nixpkgs build cannot self-update, so it becomes pinned by nixpkgs |
| uv (install.sh) | 0.13.7 (26.05: 0.11.21) | 0.13.7 | |
| nvm + node major | no nvm; `nodejs_*` packages | node 26 | |
| prek, ggshield, zizmor (uv tools) | 0.5.10 / 1.56.1 / 1.32.0 | same | |
| skills (npm) | `skills` 1.8.1 | 1.7.6 | same project not verified |
| gh-aw, gh-stack (gh extensions) | 1.0.1 / 0.3.0 | unpinned | |
| herdr | 0.9.5 | 0.9.5 | |
| oh-my-zsh, powerlevel10k | 2026-11-02 / 1.20.15 | commit / v1.20.0 | HM `programs.zsh.oh-my-zsh` |
| hugo, tailscale (personal) | 0.170.0 / 1.104.6 | 0.169.0 / apt | NixOS `services.tailscale` |
| win32yank (clipboard bridge) | absent | 0.1.1 | section 9 |
| wslu | not found | n/a | `wsl-open` 2.2.1 exists |
| wsl2-ssh-agent, wsl-vpnkit, nix-ld | 0.9.7 / 0.4.1 / 2.0.7 | n/a | |

Stable 26.05 lags noticeably for fast-moving CLIs (copilot 1.0.61 vs 1.0.108; uv 0.11.21 vs 0.13.7), which matters for the stable-vs-unstable decision.

## 8. Docker and Podman

- Native Docker: plain `virtualisation.docker.enable = true` plus `docker` group; NixOS-WSL removed its `wsl.docker-native` workaround as "no longer required" ([modules/default.nix L15-16](https://github.com/nix-community/NixOS-WSL/blob/main/modules/default.nix#L15-L16), [tests/docker/docker-native.nix](https://github.com/nix-community/NixOS-WSL/blob/main/tests/docker/docker-native.nix)). Options include `enableOnBoot`, `daemon.settings`, and `virtualisation.docker.rootless` ([docker.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/virtualisation/docker.nix), [docker-rootless.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/virtualisation/docker-rootless.nix)).
- Docker Desktop: `wsl.docker-desktop.enable` (above); frankper's WSL host uses this route (`containerRuntime = "none"`) ([settings.nix](https://gitlab.com/frankper/the-one-nix/-/blob/main/hosts/wsl/settings.nix)). [#548](https://github.com/nix-community/NixOS-WSL/issues/548) notes there are no tests for it.
- Podman: `virtualisation.podman.{enable,dockerCompat,dockerSocket.enable}`; both `dockerCompat` and `dockerSocket` assert against `virtualisation.docker.enable` ([podman/default.nix L82-100, L333-339](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/virtualisation/podman/default.nix)). frankper warns some WSL2 kernels need cgroup/network tuning for in-distro runtimes (secondary, unverified).
- Slow Docker startup was observed to push WSL past its init timeout ([#888 comment](https://github.com/nix-community/NixOS-WSL/issues/888)).

## 9. Windows interop

- PATH: `appendWindowsPath` (WSL) and `wsl.interop.includePath` (NixOS-WSL) both default on (section 5). Interop itself is binfmt; `wsl.interop.register` re-registers it when other binfmt handlers exist ([interop.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/interop.nix)); [#1109](https://github.com/nix-community/NixOS-WSL/issues/1109) (open) reports activation failing in `systemd-binfmt.service` with `register = true` + `boot.binfmt.emulatedSystems`.
- `WSLENV` shares variables across the boundary with `/p /l /u /w` flags ([MS filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)).
- Clipboard/open: `clip.exe`, `explorer.exe`, `powershell.exe` work via interop like on Ubuntu. win32yank and wslu are not in nixpkgs (section 7), so the `pbcopy`/`open` aliases need either the `.exe` tools, `wsl-open`, or a small derivation fetching win32yank's Windows release (it is a Windows `.exe`, so nix-ld is not involved). [#700](https://github.com/nix-community/NixOS-WSL/issues/700) asks for a Windows-compatible `wl-copy` (open).
- **SSH (ADR 0006).** Two options:
  - Keep copying `%USERPROFILE%\.ssh\id_ed25519`: an HM activation script or a user oneshot reading `/mnt/c/Users/<you>/.ssh` (the key cannot go through the Nix store, which is world-readable).
  - `wsl.ssh-agent.enable`: `wsl2-ssh-agent` serves a socket in WSL and relays through a `PowerShell.exe` child to the Windows `ssh-agent.exe` named pipe; needs the Windows "OpenSSH Authentication Agent" service running ([wsl2-ssh-agent README](https://github.com/mame/wsl2-ssh-agent), [ssh-agent.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/ssh-agent.nix)). This is a different chain from the `npiperelay` setup ADR 0006 rejected, but it still fails whenever the Windows agent or interop is down, and it runs as a systemd user service (section 6 caveats). Whether it finds `PowerShell.exe` without the Windows PATH in the user-manager environment is unverified.
  - GitHub key upload via `gh` stays a script either way. Neither option is declarative.
- Git Credential Manager (if HTTPS remotes are ever used): `git config --global credential.helper "/mnt/c/Program\ Files/Git/ucrt64/bin/git-credential-manager.exe"` (Git for Windows >= 2.56; `mingw64` for older) ([GCM wsl.md](https://github.com/git-ecosystem/git-credential-manager/blob/main/docs/wsl.md)). With HM, `programs.git.extraConfig.credential.helper`.
- Files: keep work in the Linux FS; `/mnt/c` is slower for Linux tools ([MS filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)). Windows reaches the distro at `\\wsl.localhost\NixOS` ([greghilston](https://www.greghilston.com/post/nixos-on-wsl/)).

## 10. Networking, proxy, CA

- **Corporate CA (ADR 0007).** NixOS trusts extra roots via `security.pki.certificateFiles` (list of PEM paths) or `security.pki.certificates` (PEM strings); they are concatenated into `/etc/ssl/certs/ca-certificates.crt` (also linked at `ca-bundle.crt` and `/etc/pki/tls/certs/ca-bundle.crt`) ([ca.nix L43-117](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/security/ca.nix)). The nix-daemon gets `CURL_CA_BUNDLE = security.pki.caBundle` ([nix-daemon.nix L332-336](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/system/nix-daemon.nix)). NixOS does not set `SSL_CERT_FILE`/`NODE_EXTRA_CA_CERTS`/`REQUESTS_CA_BUNDLE` globally (no match in `nixos/modules` shell environment), so today's exports remain needed for uv/node/requests.
- Gotchas specific to this repo:
  - The cert must be PEM; Windows' default export is DER (ADR 0007). NixOS has no `update-ca-certificates`, and a stock image may not have `openssl` until the first rebuild succeeds, so export it from certmgr as "Base-64 encoded X.509" for NixOS (workflow inference).
  - A path under `/mnt/c` is outside the flake; pure evaluation can't read it. Either commit the CA (it is a public certificate, but naming the employer's proxy root in a public repo is the same exposure ADR 0002 avoids), copy it into a gitignored path read with `--impure`, or put it in a private flake input.
- **Bootstrap through Zscaler (chicken-and-egg).** [#918](https://github.com/nix-community/NixOS-WSL/issues/918): a user behind TLS inspection couldn't install anything on a fresh NixOS-WSL; the maintainer says to build a tarball with `security.pki.*` set ([building.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/building.md)). Options:
  1. Build the work image in CI or on a personal machine with the CA baked in (needs the CA available there).
  2. One-off: Nix uses `ssl-cert-file`, overridable by `NIX_SSL_CERT_FILE` then `SSL_CERT_FILE` ([Nix conf-file](https://nix.dev/manual/nix/stable/command-ref/conf-file.html)), and root uses the local store directly because `/nix/var/nix` is writable ("auto" store, [store types](https://nix.dev/manual/nix/stable/store/types/)). So `sudo env NIX_SSL_CERT_FILE=/path/bundle.pem nixos-rebuild switch ...` with a bundle of the system CAs plus Zscaler should let the first rebuild download. Inference from the docs; not tested.
  3. Install personally (off the work network), rebuild with the CA, then use at work.
- **Package mirrors.** `UV_DEFAULT_INDEX` / `NPM_CONFIG_REGISTRY` stay env vars. Nix itself needs `cache.nixos.org` and GitHub (flake inputs) reachable; if the work network blocks them, Nix needs `substituters`/`extra-substituters` pointing at an internal cache ([Nix conf-file](https://nix.dev/manual/nix/stable/command-ref/conf-file.html)). Whether `cache.nixos.org` is reachable at work is a fact to check, not a research finding.
- **Proxy/VPN/DNS (Windows side, distro-agnostic).** `.wslconfig [wsl2]`: `networkingMode=mirrored` (Win 11 22H2+; "Improved networking compatibility for VPNs", IPv6, localhost to Windows), `dnsTunneling` (default on, 22H2+), `autoProxy` ("Enforces WSL to use Windows' HTTP proxy information"), `firewall` ([MS wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config), [MS networking](https://learn.microsoft.com/en-us/windows/wsl/networking)). Mirrored mode is needed for `wsl.usbip` with `127.0.0.1` ([usbip.nix L29-37](https://github.com/nix-community/NixOS-WSL/blob/main/modules/usbip.nix)). `wsl-vpnkit` is packaged (0.4.1); [#262](https://github.com/nix-community/NixOS-WSL/issues/262) has a user-written service, not a module. If NixOS manages DNS itself, set `wsl.wslConf.network.generateResolvConf = false` and `networking.nameservers` (module warns otherwise; [#1046](https://github.com/nix-community/NixOS-WSL/pull/1046) fixed resolvconf in 2605).

## 11. Secrets and the env file

- **sops-nix:** decrypts at activation into `/run/secrets` (or `$XDG_RUNTIME_DIR/secrets.d` via its HM module); keys are age (incl. ssh-to-age from an ed25519 key), SSH host keys or GPG; supports dotenv files and templates with `config.sops.placeholder.<name>`; the key must exist on the machine; secrets are not available at eval time ([sops-nix README](https://github.com/Mic92/sops-nix)).
- **agenix:** age-encrypted files keyed to SSH public keys, decrypted at activation, referenced via `config.age.secrets.<name>.path`; NixOS and HM modules ([agenix README](https://github.com/ryantm/agenix)).
- **Fit with ADR 0010.** Both still leave values in plain files at runtime; the gain is that encrypted values can be committed. On WSL the decryption key's delivery is the open question; frankper keeps `enableSops = false` on WSL because "no age key delivery inside WSL yet" ([settings.nix](https://gitlab.com/frankper/the-one-nix/-/blob/main/hosts/wsl/settings.nix)). The machine key ADR 0006 already copies from Windows could serve as the age identity via ssh-to-age (inference). Keeping the plain `.env` and sourcing it from zsh via HM `programs.zsh.envExtra` is the zero-change path (HM option exists in the zsh module; not separately cited).
- Do not put secrets in Nix expressions: everything in `/nix/store` is world-readable (general Nix property; not re-verified here).

## 12. Pinning and updates

- **Flake model:** every input is pinned by rev/hash in `flake.lock`; `nix flake update` (all) or `nix flake update <input>` bumps; packages follow whichever nixpkgs revision is locked. This replaces most `# renovate:` comments: you no longer pin gh/grype/uv individually, you pin nixpkgs.
- **Renovate `nix` manager:** matches `flake.nix`, supports input updates for `flake.lock` and `lockFileMaintenance` "delegated to the underlying package manager" (it runs `nix`), datasource `git-refs` only, beta, `enabled: false` by default; `depName` = input name, `packageName` = source URL ([index.ts](https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/nix/index.ts), [readme.md](https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/nix/readme.md), docs for 44.253.0 (latest release 2026-11-19)). This repo's `renovate.json` uses `enabledManagers`, so `nix` must be added there as well as enabled. Self-hosted runs need `nix` installable by containerbase; a forum report of `install-tool nix` failing exists (secondary, [discourse](https://discourse.nixos.org/t/support-for-nix-updates-in-renovate/23248)); verify on first run.
- Alternatives: a scheduled workflow running `nix flake update` and opening a PR (dmadisetti's `update-flake.yml`, weekly, [workflow](https://github.com/dmadisetti/.dots/blob/template/.github/workflows/update-flake.yml)); NixOS-WSL itself uses Renovate lock-file maintenance (its `renovate/main-lock-file-maintenance-*` branches and "chore(deps): lock file maintenance" commits).
- Things Nix does not pin for you: agent-skill sources (ADR 0008) unless fetched as flake inputs or `fetchFromGitHub`; `npx -y snyk@latest`; anything `curl | sh`. Fetchers in Nix need a hash per version, so Renovate's regex manager can bump the version but not the hash (inference).
- Stable vs unstable: stable gets security backports but lags CLIs (section 7); a common pattern is stable system + an `unstable` nixpkgs input for selected packages (frankper has `channel = "stable"` with a `modules/nixos/unstable` module, [repo](https://gitlab.com/frankper/the-one-nix)).
- ADR 0005 drift found while reading: ADR says a three-day buffer, `.github/renovate.json` has `minimumReleaseAge: "7 days"`.

## 13. CI

- **Evaluation/build on Ubuntu runners:** `nix flake check` and/or `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`; NixOS-WSL's own checks build each `checks.<system>.<name>` in a matrix over x86_64 and aarch64 runners and include a check that builds full toplevels with changed usernames ([run_checks.yml](https://github.com/nix-community/NixOS-WSL/blob/main/.github/workflows/run_checks.yml), [checks/username.nix](https://github.com/nix-community/NixOS-WSL/blob/main/checks/username.nix)). Nix is installed with `cachix/install-nix-action` pinned by SHA (31.11.3) ([install-nix action](https://github.com/nix-community/NixOS-WSL/blob/main/.github/actions/install-nix/action.yml)).
- **Real WSL on Windows runners:** NixOS-WSL builds `nixos.wsl` on Ubuntu, uploads it, then on `windows-latest` runs `wsl --update` and Pester tests that install and drive the distro (`basic-functionality`, `systemd-user`, `docker`, `envfs`, `login-shell`, `username-change`, ...) ([run_build.yml](https://github.com/nix-community/NixOS-WSL/blob/main/.github/workflows/run_build.yml), [run_tests.yml](https://github.com/nix-community/NixOS-WSL/blob/main/.github/workflows/run_tests.yml), [tests/](https://github.com/nix-community/NixOS-WSL/tree/main/tests)). This could replace ADR 0009's "converge twice in a container" and test what that container never could (wsl.conf, interop, user services).
- **Idempotence:** the "second run reports changed=0" property has no direct analog; a build is a pure function of the lock, and activation is atomic. The equivalent assertion is "builds" plus behavior tests (the Pester style) (inference).
- **dmadisetti:** `nix flake check` on push/PR plus weekly flake update PRs ([flake.yml](https://github.com/dmadisetti/.dots/blob/template/.github/workflows/flake.yml)). **frankper:** GitLab CI with per-host `nix eval` jobs instead of one `nix flake check` because the monolithic check OOM'd ([.gitlab-ci.yml](https://gitlab.com/frankper/the-one-nix/-/blob/main/.gitlab-ci.yml)).
- prek hooks would gain Nix linters (nixpkgs-fmt is what NixOS-WSL checks, [checks/](https://github.com/nix-community/NixOS-WSL/tree/main/checks); frankper uses statix).

## 14. Coexistence and migration

- Side by side: WSL runs multiple distros; install NixOS under its own name (`--name`) and keep Ubuntu until done. `wsl -s` switches the default ([MS basic commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)).
- Interaction risk: user-session startup fails when another distro with the same UID is already running ([#888](https://github.com/nix-community/NixOS-WSL/issues/888), reproduced on Ubuntu 26.04 + Rocky). Running Ubuntu and NixOS (both uid 1000) side by side may hit this; start order matters per that report.
- Backup Ubuntu first: `wsl --export <Distro> <file>` (tar, or `--vhd` for `.vhdx`), restore with `wsl --import` or `wsl --import-in-place` for a vhdx ([MS basic commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)).
- Moving home data: from NixOS, Ubuntu's files are reachable at `\\wsl.localhost\Ubuntu-26.04\...` from Windows; copying from one distro to another directly is not documented in the sources read (unverified path inside WSL: `/mnt/wsl` only shows explicitly mounted disks). Practical route: export or rsync over `/mnt/c` as a staging area, accepting `/mnt/c` slowness ([MS filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)).
- Rollback: `nixos-rebuild switch --rollback`, `nixos-rebuild list-generations` ([nixos-rebuild(8)](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd)); there is no boot menu in WSL, so a broken generation that won't start is reached via the recovery shell `--system ...-link` ([recovery-shell.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/troubleshooting/recovery-shell.md)). [#396](https://github.com/nix-community/NixOS-WSL/issues/396) (rollback through launcher) is open; [#566](https://github.com/nix-community/NixOS-WSL/issues/566) reports `list-generations` errors; [#1042](https://github.com/nix-community/NixOS-WSL/issues/1042) reports a recovery shell shebang failure.
- Changes to `wsl.conf` apply after the distro fully stops (~8 s, or `wsl --terminate`) ([MS wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)), as today.

## 15. Known issues and gotchas

| Issue | Status | Impact here |
| --- | --- | --- |
| [#918](https://github.com/nix-community/NixOS-WSL/issues/918) missing corporate CA on fresh install | open | Work bootstrap (section 10) |
| [#888](https://github.com/nix-community/NixOS-WSL/issues/888) user session fails if another distro is running | open, upstream WSL | herdr, ssh-agent bridge, sops HM |
| [#375](https://github.com/nix-community/NixOS-WSL/issues/375) `systemctl --user` "Failed to connect to bus" | open, upstream WSL | herdr |
| [#1074](https://github.com/nix-community/NixOS-WSL/issues/1074) user activation errors on `switch` in headless WSL | open | rebuild UX if `guiApplications=false` |
| [#171](https://github.com/nix-community/NixOS-WSL/issues/171) environment/PAM tracking | open | ADR 0011 |
| [#472](https://github.com/nix-community/NixOS-WSL/issues/472) `environment.sessionVariables.PATH` breaks rebuild | open | PATH handling |
| [#846](https://github.com/nix-community/NixOS-WSL/issues/846), [#1112](https://github.com/nix-community/NixOS-WSL/issues/1112) drives not mounted (envfs) | open | avoid `services.envfs` or test |
| [#1109](https://github.com/nix-community/NixOS-WSL/issues/1109) binfmt activation failure | open | only with emulated systems |
| [#1116](https://github.com/nix-community/NixOS-WSL/issues/1116) startMenuLaunchers lag one rebuild | open | cosmetic |
| [#384](https://github.com/nix-community/NixOS-WSL/issues/384) `/etc/nixos/configuration.nix` read-only in fresh image | open | edit via `sudo nixos-rebuild edit` or move to flake |
| [#604](https://github.com/nix-community/NixOS-WSL/issues/604) flake docs unclear | open | expect to read module source |
| [#454](https://github.com/nix-community/NixOS-WSL/issues/454) GPU accel needs `LD_LIBRARY_PATH` hacks | open | not in scope today |

Other: `networking.extraHosts` does nothing while `generateHosts` is true ([wsl-conf.nix L126-127](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L126-L127)); `programs.ssh.startAgent` fails when user units don't start (#375 comment).

## 16. Example repos

- **dmadisetti/.dots** (default branch `template`, pushed 2026-11-16): one flake for several hosts (`gce`, `momento`, `wsl`); `nix/{common,home,machines,display,lib}`; `utils.mkComputer` (NixOS + HM module) and `utils.mkHome` (standalone HM); private values via a mustache-templated `sensitive` flake input; `nix flake check` CI and weekly update PRs ([flake.nix](https://github.com/dmadisetti/.dots/blob/template/flake.nix), [utils.nix](https://github.com/dmadisetti/.dots/blob/template/nix/utils.nix)). Its `nix/machines/wsl.nix` was last changed 2023-10-12 and is outdated: it sets `boot.isContainer = true` and by hand what the module now sets (root `extraGroups`, `wheelNeedsPassword`, resolv.conf/hosts, dhcpcd, firewall, emergency mode), and the repo still carries `nix/lib/syschdemd.*`, the pre-native-systemd mechanism NixOS-WSL removed ([wsl.nix](https://github.com/dmadisetti/.dots/blob/template/nix/machines/wsl.nix), [systemd/default.nix L7](https://github.com/nix-community/NixOS-WSL/blob/main/modules/systemd/default.nix#L7)). Use it for layout ideas only.
- **frankper/the-one-nix** (GitLab, pushed 2026-11-18): one flake for many hosts; each host has `hosts/<host>/{settings.nix,configuration.nix}`; `settings.nix` is a typed bag of feature flags (`isWsl`, `isWorkLaptop`, `enableSops`, `containerRuntime`, `channel = "stable"`, `stateVersion = "26.05"`); `modules/nixos/feature-gates` imports `modules/nixos/wsl` (imports `nixos-wsl.nixosModules.default`, sets `wsl.enable`, `wsl.defaultUser`, `generateResolvConf` and `startMenuLaunchers` as `mkDefault true`) and skips bootloader/kernel; shared HM tree `home/shared`; image built off-box with `just wsl-build` (wraps `tarballBuilder`) and imported with `wsl --import`; ongoing `sudo nixos-rebuild switch --flake .#wsl` ([guide](https://frankper.gitlab.io/the-one-nix/guides/manage-nixos-in-wsl/), [modules/nixos/wsl](https://gitlab.com/frankper/the-one-nix/-/blob/main/modules/nixos/wsl/default.nix), [settings.nix](https://gitlab.com/frankper/the-one-nix/-/blob/main/hosts/wsl/settings.nix)). Its settings-as-data shape is the closest analog to ADR 0002's profiles.
- **greghilston.com** (2024-12-17): manual import of `nixos-wsl.tar.gz`, `nix-channel --update`, then `ln -sf` a host file from a repo onto `/etc/nixos/configuration.nix`. Outdated against current docs: the asset is `nixos.wsl` since 2411; `wsl --install --from-file` replaces `--import` on WSL >= 2.4.4; the `dism ... VirtualMachinePlatform` step is not in current instructions; it never runs `nixos-rebuild` ([post](https://www.greghilston.com/post/nixos-on-wsl/), [install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)).

## 17. Source quality notes

- **Not read:** the Medium post (`medium.com/@piyushkumarsingh.nmims/...`) and `nixos.wiki/wiki/WSL` both returned HTTP 403 (Cloudflare challenge) to automated fetches on 2026-11-19, and a web search did not surface the Medium text. Nothing in this report relies on them.
- **wiki.nixos.org/wiki/WSL** (official wiki, last edited 2026-03-10) is thin: install via double-click of `nixos.wsl` (WSL >= 2.4.4), `wsl -d NixOS`, and a Task Scheduler + VBS trick to start the distro at login ([wiki](https://wiki.nixos.org/wiki/WSL)). It says NixOS "is not yet packaged as a official WSL distribution", consistent with open [#63](https://github.com/nix-community/NixOS-WSL/issues/63) (Windows Store package).
- **Disagreements found:** install.md's "`wheelNeedsPassword = true` ... which is the default" vs the module's `mkDefault false` (section 3); greghilston's tarball name and `--import` vs current docs (section 16); dmadisetti's hand-set WSL options vs current module defaults (section 16); MS docs list `wsl.conf` `mountFsTab` default `true` while NixOS-WSL defaults it to `false` deliberately (section 5); MS lists `[automount] ldconfig` default `true`, NixOS-WSL sets `false` because that mechanism "does not work with NixOS" ([wsl-conf.nix L31-38](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L31-L38)).

## 18. Mapping: today to Nix

| Concern today (ADR / role) | NixOS-WSL / Nix equivalent | Source |
| --- | --- | --- |
| One Ubuntu 26.04 distro, Ansible run (0001) | One `nixosConfigurations.<host>`; `nixos-rebuild switch --flake` | [nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/nix-flakes.md), [nixos-rebuild(8)](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd) |
| Bootstrap `scripts/setup` | `.wsl` image (stock or self-built with `tarballBuilder`) + first rebuild | [install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md), [building.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/building.md) |
| Layered profiles base/personal/work + local file (0002) | NixOS module merging (lists concatenate, `mkDefault`/`mkForce`); one host or one module per profile; local file as private flake input or `--impure` | [frankper settings](https://gitlab.com/frankper/the-one-nix/-/blob/main/hosts/wsl/settings.nix), [dmadisetti sensitive input](https://github.com/dmadisetti/.dots/blob/template/flake.nix) |
| Minimal roles, verify.yml (0003) | NixOS/HM modules; verification moves to build + CI tests | [run_tests.yml](https://github.com/nix-community/NixOS-WSL/blob/main/.github/workflows/run_tests.yml) |
| Tool lists (0004) | `environment.systemPackages` / `home.packages` lists | [HM NixOS module](https://nix-community.github.io/home-manager/installation/nixos.html) |
| Pinned versions + Renovate regex (0005) | `flake.lock`; Renovate `nix` manager (beta) or scheduled `nix flake update` | [Renovate nix](https://docs.renovatebot.com/modules/manager/nix/) |
| Copy Windows SSH key (0006) | Activation script copy, or `wsl.ssh-agent.enable` | [ssh-agent.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/ssh-agent.nix) |
| Zscaler CA (0007, `certificates` role) | `security.pki.certificateFiles`; image built with it for bootstrap | [ca.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/security/ca.nix), [#918](https://github.com/nix-community/NixOS-WSL/issues/918) |
| `SSL_CERT_FILE` / `NODE_EXTRA_CA_CERTS` / `REQUESTS_CA_BUNDLE` | `environment.variables` or HM `home.sessionVariables` (still needed) | [ca.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/security/ca.nix) |
| Package mirrors in `.env` (0007, 0010) | Unchanged env vars; plus Nix `substituters` if `cache.nixos.org` is blocked | [Nix conf-file](https://nix.dev/manual/nix/stable/command-ref/conf-file.html) |
| Agent instructions, skills, MCP merge (0008) | HM `programs.claude-code` / `programs.mcp` (store-managed), or activation scripts for mutable merges | [HM modules](https://github.com/nix-community/home-manager/tree/release-26.05/modules/programs), [HM dotfiles](https://nix-community.github.io/home-manager/usage/dotfiles.html) |
| CI converge twice in container (0009, 0012) | `nix flake check` / toplevel build; optional `.wsl` + Pester on `windows-latest` | [run_checks.yml](https://github.com/nix-community/NixOS-WSL/blob/main/.github/workflows/run_checks.yml), [run_tests.yml](https://github.com/nix-community/NixOS-WSL/blob/main/.github/workflows/run_tests.yml) |
| `.env` file (0010) | Keep (source from zsh), or sops-nix/agenix with key from Windows | [sops-nix](https://github.com/Mic92/sops-nix), [agenix](https://github.com/ryantm/agenix) |
| `environment.d/999-wsl.conf` for user services (0011) | HM `systemd.user.sessionVariables` / `systemd.user.extraConfig` for static values; runtime step for Windows PATH | [HM systemd.nix](https://github.com/nix-community/home-manager/blob/release-26.05/modules/systemd.nix), [#171](https://github.com/nix-community/NixOS-WSL/issues/171) |
| `/etc/wsl.conf` template (system role) | `wsl.wslConf.*` | [wsl-conf.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix) |
| Hostname via wsl.conf | `networking.hostName` (feeds `wslConf.network.hostname`) | [wsl-conf.nix L100-105](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-conf.nix#L100-L105) |
| apt, unattended-upgrades, norecommends | Gone; updates are lock bumps | n/a |
| sudo/docker groups, sudoers file | `users.users.<u>.extraGroups`, `security.sudo.*` | [wsl-distro.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/wsl-distro.nix) |
| Docker CE apt repo | `virtualisation.docker.enable` (or `wsl.docker-desktop`, Podman) | [docker-native test](https://github.com/nix-community/NixOS-WSL/blob/main/tests/docker/docker-native.nix) |
| zsh + oh-my-zsh + plugins pinned (zsh role) | HM `programs.zsh` + `oh-my-zsh`; plugins as nixpkgs or `fetchFromGitHub` | [HM zsh](https://github.com/nix-community/home-manager/tree/release-26.05/modules/programs/zsh) |
| git role | HM `programs.git` | [HM git.nix](https://github.com/nix-community/home-manager/blob/release-26.05/modules/programs/git.nix) |
| herdr binary + user unit + linger (herdr role) | nixpkgs `herdr` + hand-written `systemd.user.services.herdr` | section 6 |
| curl-installed CLIs (claude, copilot, uv, nvm) | nixpkgs packages, or nix-ld + keep installers | section 7 |
| win32yank clipboard bridge | `clip.exe`/`powershell.exe`, or a derivation for the Windows binary | section 9 |
| VS Code `code .` via Windows PATH | Same PATH; Remote-WSL server needs nix-ld | [vscode.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/vscode.md) |

## 19. Decisions for planning

1. **Target: NixOS-WSL vs Nix + home-manager on Ubuntu (vs both).**
   - NixOS-WSL: one declarative, rollback-able system, `wsl.conf`/CA/docker/users in Nix. Costs: nix-ld or nixpkgs for every foreign binary, the Zscaler bootstrap, WSL user-session issues (still present), learning curve.
   - Nix + HM on Ubuntu: keeps apt, FHS binaries, current bootstrap and CA handling; only `$HOME` becomes declarative. Costs: two package managers, Ansible (or system-manager) for the system layer.
   - Both: write HM config portable, as dmadisetti does, so HM runs as a NixOS module on NixOS-WSL and standalone elsewhere.
2. **Keep Ansible for anything?** Candidates that are machine state rather than config: copying the SSH key from Windows, adding it to GitHub, the Windows-PATH snapshot (ADR 0011), the `.env` file creation, the CA export. In Nix these become activation scripts or a small bootstrap script. The alternative is a thin script and no Ansible at all.
3. **Flakes vs channels.** Flakes give `flake.lock`, Renovate/CI integration, and `nixos-rebuild --flake` from the repo; they need enabling, docs are thin (#604), and the never-committed local file needs a pattern. Channels match the stock image but have no lock file.
4. **Home Manager: NixOS module vs standalone.** Module = one command and one lock, activation as a system unit; standalone = user-owned and portable to Ubuntu. Plus: how to handle files the agent CLIs also write (store link vs activation merge, ADR 0008).
5. **nixpkgs channel: stable 26.05, unstable, or stable + unstable overlay.** Stable lags CLIs by many versions (copilot, uv); unstable matches today's pins; 26.11 is imminent.
6. **Foreign binaries policy:** enable nix-ld globally (closest to today, VS Code Remote works), or package everything from nixpkgs and treat nix-ld as fallback. Decide for tokenuse (not in nixpkgs), agent skills, `npx` MCP servers, uv-managed Pythons.
7. **Profiles model (ADR 0002) in Nix:** one `nixosConfiguration` per profile (`personal`, `work`) sharing a base module, vs one host plus a settings attrset (frankper), and where identity and the local file go (private flake input, `--impure`, or sops).
8. **Work bootstrap through Zscaler:** self-built image with the CA (built where, holding which copy of the CA), the `NIX_SSL_CERT_FILE` one-off, or bootstrap off-network. Also whether `cache.nixos.org` and GitHub are reachable at work, and whether committing the CA to a public repo is acceptable.
9. **SSH (ADR 0006):** keep copying the key (activation script) or adopt `wsl.ssh-agent` (revisits the "chain breaks" reason ADR 0006 gave for rejecting an agent bridge).
10. **Secrets (ADR 0010):** keep the plain `.env`, or move to sops-nix/agenix, and if so how the decryption key reaches WSL.
11. **Containers:** native `virtualisation.docker`, Docker Desktop integration, or Podman (the Terraform MCP server needs one of them).
12. **ADR 0011 replacement:** how user services (herdr, ssh-agent bridge) get `WSL_DISTRO_NAME` and the Windows PATH on NixOS-WSL.
13. **Renovate:** enable the beta `nix` manager for `flake.lock` (and add `nix` to `enabledManagers`), or a scheduled `nix flake update` PR; what remains for the regex manager (skills, non-nixpkgs tools); automerge policy for nixpkgs bumps.
14. **CI:** eval/build only (`nix flake check`, toplevel per profile), add `.wsl` image + Pester on `windows-latest` (copying NixOS-WSL's setup), and how the daily "upstream rot" check (ADR 0012) maps to a lock bump.
15. **Repo layout:** keep `specs/`, add `flake.nix` + `hosts/` / `modules/{nixos,home}` (frankper-like) or `nix/{machines,home,common}` (dmadisetti-like); whether Ansible and Nix coexist in the repo during migration.
16. **Migration mechanics:** distro name, side-by-side period (watch #888 with two uid-1000 distros), `wsl --export` backup of Ubuntu, how `$HOME` data moves, and cut-over criteria.

## Sources

All accessed 2026-11-19.

NixOS-WSL (primary):

- Repo, README, `flake.nix`, `modules/*`, `utils/src/*`, `checks/*`, `tests/*`, `.github/workflows/*`, `.github/actions/install-nix/action.yml`: <https://github.com/nix-community/NixOS-WSL> (`main`, last push 2026-11-17; `release-26.05`)
- Docs source `docs/src/*` and site: <https://nix-community.github.io/NixOS-WSL/>, [install](https://nix-community.github.io/NixOS-WSL/install.html), [options](https://nix-community.github.io/NixOS-WSL/options.html)
- Releases: <https://github.com/nix-community/NixOS-WSL/releases> (2605.7.2, 2026-06-06)
- Issues: #63, #171, #262, #375, #384, #396, #454, #472, #548, #566, #604, #700, #846, #888, #918, #1042, #1069, #1074, #1109, #1112, #1116; PRs #898, #1046, #1120

Nix / NixOS / Home Manager (primary):

- nixpkgs `nixos-26.05`: `nixos/modules/security/ca.nix`, `programs/nix-ld.nix`, `virtualisation/docker.nix`, `docker-rootless.nix`, `podman/default.nix`, `services/system/nix-daemon.nix`, `system/boot/systemd/user.nix`, `doc/packages/uv.section.md`, `pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd`: <https://github.com/NixOS/nixpkgs>
- nixpkgs `nixos-unstable` `pkgs/by-name/*` for package availability (section 7)
- Nix 2.34 manual: [conf-file](https://nix.dev/manual/nix/stable/command-ref/conf-file.html), [installation](https://nix.dev/manual/nix/stable/installation/), [store types](https://nix.dev/manual/nix/stable/store/types/)
- [nixos.org/download](https://nixos.org/download/); NixOS manual 26.05 <https://nixos.org/manual/nixos/stable/> (partially read)
- Home Manager manual: [NixOS module](https://nix-community.github.io/home-manager/installation/nixos.html), [standalone](https://nix-community.github.io/home-manager/installation/standalone.html), [flakes + NixOS](https://nix-community.github.io/home-manager/nix-flakes/nixos.html), [dotfiles](https://nix-community.github.io/home-manager/usage/dotfiles.html); source `release-26.05` <https://github.com/nix-community/home-manager>
- [nix-ld](https://github.com/Mic92/nix-ld), [sops-nix](https://github.com/Mic92/sops-nix), [agenix](https://github.com/ryantm/agenix), [system-manager](https://github.com/numtide/system-manager), [wsl2-ssh-agent](https://github.com/mame/wsl2-ssh-agent)

Microsoft / other primary:

- [wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) (updated 2026-10-16), [networking](https://learn.microsoft.com/en-us/windows/wsl/networking), [basic-commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands), [filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems), [build-custom-distro](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro) (each updated 2026-06-02); [microsoft/WSL releases](https://github.com/microsoft/WSL/releases); [microsoft/WSL#9213](https://github.com/microsoft/WSL/issues/9213)
- Renovate: [nix manager docs](https://docs.renovatebot.com/modules/manager/nix/) (44.253.0), [source](https://github.com/renovatebot/renovate/tree/main/lib/modules/manager/nix)
- [Git Credential Manager WSL](https://github.com/git-ecosystem/git-credential-manager/blob/main/docs/wsl.md)

Secondary (user-supplied and others):

- [frankper: Manage NixOS in WSL](https://frankper.gitlab.io/the-one-nix/guides/manage-nixos-in-wsl/) and repo <https://gitlab.com/frankper/the-one-nix> (pushed 2026-11-18)
- [dmadisetti/.dots](https://github.com/dmadisetti/.dots) (`template` branch, pushed 2026-11-16)
- [Greg Hilston: NixOS on WSL](https://www.greghilston.com/post/nixos-on-wsl/) (2024-12-17)
- [wiki.nixos.org/wiki/WSL](https://wiki.nixos.org/wiki/WSL) (edited 2026-03-10)
- [nixos.wiki/wiki/WSL](https://nixos.wiki/wiki/WSL): not accessible (HTTP 403)
- [Medium: NixOS on WSL, the best of both worlds](https://medium.com/@piyushkumarsingh.nmims/nixos-on-wsl-the-best-of-both-worlds-bdcaba54ee58): not accessible (HTTP 403)
- [NixOS Discourse: Renovate nix support](https://discourse.nixos.org/t/support-for-nix-updates-in-renovate/23248)
