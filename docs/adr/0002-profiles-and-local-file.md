# 0002. Profiles and the local file

Status: accepted, 2026-09-24

## Context

Each machine used to carry one gitignored `inventory/group_vars/all.yml` holding both identity and the role list, with every optional role commented out. Home and work machines drifted silently, and nothing in git said what either one had. The repo is public, so work identity and corporate network details cannot be committed.

## Decision

- `profiles/base.yml` applies to every machine. `profiles/home.yml` and `profiles/work.yml` list only what they add or change.
- `~/.config/dotfiles/local.yml` holds identity, machine specifics and network values, and names the profile in `dotfiles_profile`. It lives outside the checkout so it can never be committed and survives a re-clone.
- The playbook loads base, the named profile, then the local file. Later layers override scalars and dictionaries key by key and append to lists (`combine(recursive=true, list_merge='append_rp')`).
- `scripts/setup --profile work` records the profile once; later runs need no flags.
- Role order is fixed in the playbook, not by the order roles appear in the layers, so a profile that adds `network` still gets it before anything downloads.

## Consequences

- What a work machine gets is visible in git; who it belongs to is not.
- CI converges each profile with a fixture local file.
- A profile cannot remove something `base` adds. If that is ever needed, move the item out of `base`.
