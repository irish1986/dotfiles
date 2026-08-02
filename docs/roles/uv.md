# uv

[uv](https://docs.astral.sh/uv/), the Python package and tool manager.

`uv` is the single Python tool manager for this repository, which is why `pipx` is deliberately **absent** from it: uv sidesteps PEP 668 the same way, behaves identically on 22.04, 24.04 and 26.04, and one tool means one place for tools to end up. The [ansible_tools](ansible_tools.md) and [prek](prek.md) roles both install through it, so `uv` must come before them in `dotfiles_roles`.

## Split out of the python role

uv used to live in the [python role](python.md), behind a `python_uv_enabled` flag. Two things with quite different lifecycles were sharing one role: apt-managed system packages, and a user-scoped static binary that installs its own interpreters into `~/.local/share/uv`.

The flag is gone with the split. Whether uv is installed is decided the way every other role decides it -- by appearing in `dotfiles_roles` -- rather than by a boolean inside a role that would run anyway.

`python` remains a genuine prerequisite of nothing here: uv ships a static binary and does not need the distro interpreter. Listing `python` first is still the sensible order, because the distro `python3` is what Ansible itself runs on.

## A caution about uv python install --default

`uv_python_version` is installed and marked default, which puts a **user-owned** interpreter on `PATH` ahead of `/usr/bin/python3`.

That is fine for your shell but must not leak into Ansible: with interpreter auto-discovery, every `become: true` task would have root executing an interpreter the login user can modify. `inventory/hosts.yml` therefore pins `ansible_python_interpreter` to the distro python. See [Playbook](../reference/playbook.md).

Set `uv_manage_python: false` to install uv alone and leave the interpreter choice alone.

The interpreter install previously carried `failed_when: false`, `changed_when: false` *and* a `rescue` block at once -- three layers of suppression, so any failure was invisible. Failures are real now, and `verify.yml` asserts the interpreter actually landed rather than merely that uv answers `--version`.
