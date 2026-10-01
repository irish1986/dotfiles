# Copy the Windows SSH key into the distro

Status: accepted, 2026-10-01

A machine has one SSH key: the Windows user's `%USERPROFILE%\.ssh\id_ed25519`, which you create once on Windows with `ssh-keygen`. Every run copies both halves into the distro's `~/.ssh` (the private key at 0600, a differing copy kept as a backup) and, when `gh` is logged in with the key scopes, adds the public key to GitHub as an authentication and a signing key. A run fails while Windows has no key.

Serving the key from the Windows ssh-agent through `npiperelay` was tried first and broke whenever any link in that chain was down. Generating and rotating the key from the playbook was dropped too: it was the one place the playbook wrote to Windows (0001).

## Consequences

- The distro holds a copy of the private key; a compromised distro can take it.
- A key replaced on Windows reaches the distro on its next run.
