# Layered profiles that only supply values

Status: accepted, 2026-10-01

What a machine gets comes from three layers, applied in order: `profiles/base.yml`, one named profile (`profiles/personal.yml` or `profiles/work.yml`), and the local file `~/.config/dotfiles/local.yml`. A later layer overrides scalars and dictionaries key by key and appends to lists. The local file lives outside the checkout, so identity and corporate URLs, which this public repo must not hold, can never be committed; it also names the profile.

A profile only supplies values: tool lists, the corporate CA's file name. It never chooses roles. Every role runs on every machine in the fixed order `main.yml` lists, and a role whose values are empty does nothing. An earlier version let profiles pick roles, which needed a role-order list, a role loop and a validation step to keep them consistent.

## Consequences

- What a work machine gets is visible in git; whom it belongs to is not.
- A profile cannot remove what `base` adds. If that is ever needed, move the item out of `base`.
