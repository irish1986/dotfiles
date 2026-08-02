# ansible_tools

Ansible tooling for working *on* this repository, rather than the ansible that runs it.

Installed with `uv`, not apt and not `ppa:ansible/ansible`. Three reasons:

- The PPA ships the batteries-included `ansible` package, whose bundled collections shadow the five pinned in `collections/requirements.yml`.
- The PPA can have no pocket at all for a brand-new LTS.
- jammy's archive `ansible-core` is 2.12, below the `>=2.16` those collections declare, so the distro package cannot satisfy this repository on 22.04.

`bitwarden-sdk` is injected into the `ansible-core` environment rather than installed separately. `bitwarden.secrets.lookup` runs controller-side and must be importable by the interpreter running `ansible-playbook`; installing it as its own tool puts it in a virtualenv Ansible cannot import from. `verify.yml` asserts the import actually works.

`ansible_tools_remove_apt_install` defaults to **false** on purpose. On a machine bootstrapped from apt or the PPA, the ansible running the play *is* that package, and removing it mid-run pulls the interpreter out from under the playbook. Enable it only once the uv-managed ansible is ahead on `PATH`.

Variables are prefixed `ansible_tools_`, not `ansible_`: that namespace belongs to gathered facts, and a role that shadows one fails in ways that are hard to trace.
