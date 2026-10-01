# The work network

Status: accepted, 2026-10-01

The work network inspects TLS through Zscaler and blocks some public registries. There is no explicit proxy to configure, so the repo handles two things only:

- **The corporate CA.** `profiles/work.yml` names `zscaler.cer`, exported once on Windows to `C:\Users\<you>`. It is converted to PEM (Windows exports DER whatever the extension) and added to the system trust store, and every shell and every run points tools that ship their own CA list (uv, node, Python requests) at that store. `scripts/setup` does this before it downloads anything, and the `certificates` role runs first in the playbook for the same reason. A work run without the file fails rather than producing confusing TLS errors later.
- **Package mirrors.** The internal PyPI mirror (uv's default index), uv's Python download mirror and the npm registry are URLs in the local file, never in the repo. They are read anonymously. `scripts/setup` reads them too, because it installs ansible-core through uv before the playbook exists; the playbook writes them to `~/.config/uv/uv.toml` and `~/.config/npm/npmrc`.

The earlier `network` role also set an HTTP proxy for the shell, apt, docker, git and the run itself; none of it was needed behind Zscaler.
