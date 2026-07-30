# python

Python toolchain and [uv](https://docs.astral.sh/uv/).

`pipx` is deliberately **absent**. uv is the single Python tool manager for this
repository: it sidesteps PEP 668 the same way, behaves identically on 22.04,
24.04 and 26.04, and one tool means one place for tools to end up. The
[ansible_tools](ansible_tools.md) and [prek](prek.md) roles both depend on it, so
`python` must come before them in `dotfiles_roles`.

## A caution about uv python install --default

`python_version` is installed and marked default, which puts a **user-owned**
interpreter on `PATH` ahead of `/usr/bin/python3`.

That is fine for your shell but must not leak into Ansible: with interpreter
auto-discovery, every `become: true` task would have root executing an interpreter
the login user can modify. `inventory/hosts.yml` therefore pins
`ansible_python_interpreter` to the distro python. See
[Playbook](../../docs/reference/playbook.md).

The interpreter install previously carried `failed_when: false`,
`changed_when: false` *and* a `rescue` block at once -- three layers of
suppression, so any failure was invisible. Failures are real now; `verify.yml`
catches them.
