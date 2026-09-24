# 0007. Ubuntu 24.04 and 26.04

Status: accepted, 2026-09-24

## Context

22.04 needed its own variable files and missing-package workarounds (no `eza`, no `gh`, old `ansible-core` in the archive), and a CI matrix leg of its own.

## Decision

Support and test Ubuntu 24.04 and 26.04 only. No codename is hardcoded: third-party apt repositories are probed for this release's suite and fall back to `noble` when the vendor lags.

## Consequences

- A 22.04 machine is refused by the playbook's first assertion. Upgrade it first.
