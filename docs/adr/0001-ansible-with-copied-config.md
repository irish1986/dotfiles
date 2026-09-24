# 0001. Ansible, with copied config

Status: accepted, 2026-09-24

## Context

The repo has been an Ansible playbook for years, and the install / configure / verify split in each role works. The alternatives considered were chezmoi (or plain symlinks) for dotfiles with Ansible only installing packages, and symlinking config files into the checkout so an edit in `$HOME` is an edit in the repo.

## Decision

Stay on Ansible for everything. Config files keep being deployed with `copy` / `template`: the repo is the source of truth and a change reaches `$HOME` on the next run.

## Consequences

- One tool, one mental model, one place to look.
- Editing `~/.zshrc` directly is lost on the next run. Edit the file under `roles/` and re-run with `--tags <role>`.
- Files that an application rewrites itself (Claude Code's `settings.json`, gh's `config.yml`) are not templated; they are either left alone or changed key by key through the application's own CLI.
