# Minimal roles

Status: accepted, 2026-10-01

A role is `tasks/main.yml`, `tasks/verify.yml`, and whatever `defaults/`, `files/`, `templates/` and `handlers/` it actually uses. There is no `meta/` or `vars/`, no per-OS install file chosen at run time, no install/configure split, and no structure linter enforcing any of it. Seven roles remain, in run order: certificates, system, zsh, tools, ssh, git, herdr.

Each role still ends by asserting that what it installed works (`verify.yml`, skipped under `--check`), so a run cannot quietly do nothing. The previous six-to-eight-file skeleton per role existed to support other platforms this repo no longer targets (0001).
