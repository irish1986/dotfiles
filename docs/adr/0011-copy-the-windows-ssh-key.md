# 0011. Copy the Windows SSH key

Status: accepted, 2026-09-25. Supersedes [0010](0010-one-ssh-key-per-machine.md).

## Context

ADR 0010 kept the private key out of the distros by serving it from the Windows `ssh-agent` through `npiperelay` and a systemd user socket. It needed a UAC prompt, a downloaded Windows binary, masking Ubuntu's own agent and an `SSH_AUTH_SOCK` override in `.zshenv`, and ssh broke whenever any link in that chain was down, including in every shell started before the switch. That was too much machinery for what it bought.

## Decision

A machine still has exactly one SSH key, and on WSL it is still the Windows user's `%USERPROFILE%\.ssh\id_ed25519`, generated there with `ssh-keygen.exe` when missing. Every run copies both halves into the distro's `~/.ssh`, the private key at 0600. A distro copy that differs is overwritten, and the file it replaces is kept as a timestamped backup. ssh and git use the local file; Ubuntu's own `ssh-agent` is left alone.

Key generation, adding the key to GitHub and `scripts/setup --rotate-ssh-key` are unchanged from 0010.

## Consequences

- ssh from WSL does not depend on the Windows agent or on interop once the run is done.
- Every distro holds a copy of the private key. A compromised distro can take it.
- A rotation reaches a distro on its next run, not immediately. The verify step fails when the distro's copy does not match Windows.
- A key with a passphrase asks for it on first use; `AddKeysToAgent` then keeps it in the distro's agent for the session.
- The Windows `ssh-agent` service that 0010 enabled is left as it is; nothing uses it.
