# 0010. One SSH key per machine

Status: accepted, 2026-09-25

## Context

The workstation runs several WSL distros. Each one needed its own key, or a copy of the Windows key. Separate keys meant registering and rotating every one of them on GitHub and on every host. Copies put the private key in every distro, and the copy only filled an empty `~/.ssh`, so a key rotated on Windows never reached the distros.

## Decision

A machine has exactly one SSH key.

- On WSL it is the Windows user's key, `%USERPROFILE%\.ssh\id_ed25519`. The Windows `ssh-agent` service holds it, and every distro reaches that agent through a systemd user socket that starts `npiperelay.exe` per connection. No distro holds the private key. `~/.ssh/id_ed25519.pub` is a symlink to the Windows public key; ssh's `IdentityFile` and git's `user.signingkey` name it.
- Elsewhere (plain Ubuntu, CI) it is the host's own `~/.ssh/id_ed25519`.
- The run generates the key when it is missing, without a passphrase, since the run is unattended. A key you generated yourself is never replaced.
- The run makes the Windows `ssh-agent` service automatic and started, through one UAC prompt, when it is not.
- When `gh` is logged in with the key scopes, the run adds the key to GitHub as an authentication and a signing key.
- `scripts/setup --rotate-ssh-key` replaces the key: the old pair is kept as `.old` and dropped from the agent, a new key is generated and loaded, and on GitHub the old key stops being an authentication key but stays a signing key, so commits signed with it remain Verified.
- Any distro may generate or rotate the Windows key. `wsl_global_owner` covers only `.wslconfig`, Terminal settings and fonts.

## Consequences

- Rotation happens in one place and every distro uses the new key at once, without a run. Hosts that trusted the old public key still need the new one by hand.
- ssh from WSL depends on the Windows agent and on interop. If either is down, no distro can authenticate.
- A compromised distro can use the key while the agent runs, but cannot copy it.
- A generated key has no passphrase. To have one, generate the key on Windows before the first run; `scripts/setup` then asks for the passphrase once to load it into the agent.
- A private key already in a distro is left alone and reported; it is no longer used.
- Sharing the Windows `~/.ssh/config` host entries with the distros is not part of this decision.
