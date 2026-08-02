# python

The distro Python toolchain: `python3`, `pip`, `venv` and the build headers, from apt.

That is the whole scope. uv, the interpreters uv manages, and every Python tool this repository installs belong to the [uv role](uv.md) -- they used to live here behind a `python_uv_enabled` flag, which put apt-managed system packages and a user-scoped binary with its own interpreter tree in the same role. `pipx` is deliberately absent from both.

## Why the absolute path

`python_binary` is `/usr/bin/python3` rather than a bare `python3`.

Once the uv role has run `uv python install --default`, a user-owned interpreter sits on `PATH` ahead of the distro one. A bare name would verify that interpreter, which is precisely the one this role does not install and does not manage. See [Playbook](../reference/playbook.md) for why the distinction matters to `become: true` tasks.
