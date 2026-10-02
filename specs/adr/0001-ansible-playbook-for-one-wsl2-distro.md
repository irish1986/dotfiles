# One WSL2 Ubuntu 26.04 distro

Status: accepted, 2026-10-01

The repo sets up one thing: a WSL2 distro running Ubuntu 26.04, with its shell, tools and their configuration, as an Ansible playbook that is safe to run again at any time (a second run reports `changed=0`). Config files are copied from the repo rather than symlinked, so a run is the only way they change.

Earlier versions also supported 24.04, plain Ubuntu hosts, several distros sharing one Windows user, and wrote to Windows itself: `.wslconfig`, Windows Terminal settings, fonts and SSH keys. That reach is what made the repo hard to follow, so it was cut back:

- **26.04 only.** No release-specific files, no fallback suites for vendors that lag a release. A plain Ubuntu 26.04 container still converges, with the WSL-only tasks skipped, because that is how CI tests the playbook.
- **The playbook reads Windows and never writes it.** It reads the SSH key and, on a work machine, the corporate CA certificate from the Windows home. Terminal settings, `.wslconfig` and the Nerd Font are one-time steps in the README.
- **No secrets.** Secret delivery (Infisical) was removed, to be revisited on its own. Tokens that tools need live in a gitignored env file (0010).
