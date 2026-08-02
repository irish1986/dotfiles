# Role layout

Every role has the same shape:

```text
roles/<role>/
  defaults/main.yml         user-tunable knobs, <role>_ prefixed
  vars/main.yml             invariants: URLs, binary paths, service names
  vars/Ubuntu-22.yml        per-release facts, e.g. package name deltas
  meta/main.yml             galaxy_info + dependencies: []
  tasks/main.yml            orchestrator: include_vars / include_tasks only
  tasks/install/Ubuntu.yml  package manager, /etc, system paths
  tasks/configure.yml       dirs, dotfiles, templates. Never become
  tasks/verify.yml          asserts the thing is actually installed
  handlers/main.yml
  files/  templates/
```

## The orchestrator is only an orchestrator

`tasks/main.yml` contains no module calls other than `include_vars` and `include_tasks`. That constraint is what keeps the generic/OS-specific split legible — and it is enforced, because it is exactly what drifted before: seven roles had bolted generic tasks onto the end of their dispatcher, so "what is OS-specific here" could only be answered by reading the whole file.

## Dispatch uses first_found, not stat

```yaml
- name: Docker | Install
  ansible.builtin.include_tasks: "{{ docker_install_tasks }}"
  vars:
    docker_install_tasks: "{{ lookup('ansible.builtin.first_found', docker_install_lookup) }}"
    docker_install_lookup:
      files:
        - "{{ ansible_distribution }}-{{ ansible_distribution_major_version }}.yml"
        - "{{ ansible_distribution }}.yml"
        - "{{ ansible_os_family }}.yml"
      paths:
        - "{{ role_path }}/tasks/install"
```

Note there is no `skip: true` on the *tasks* lookup, unlike the vars lookup above it. That asymmetry is the point: an unsupported distribution, or a filename typo, now fails the play.

The previous pattern was `stat` the file and `when: exists`. A role once shipped `tasks/Ubunu.yml` — one letter short — and the stat simply returned false, so the role was a permanent silent no-op with a green playbook. `first_found` without `skip: true` cannot do that.

The ladder also gives per-release overrides for free: `Ubuntu-26.yml` falls back to `Ubuntu.yml`, which falls back to `Debian.yml`.

## verify.yml

```yaml
- name: Docker | Query the installed client version
  ansible.builtin.command: "{{ docker_binary }} --version"
  register: docker_version_check
  changed_when: false
  failed_when: false

- name: Docker | Assert the client is usable
  ansible.builtin.assert:
    that:
      - docker_version_check.rc == 0
      - "'Docker version' in docker_version_check.stdout"
```

A role that must end by asserting its own binary works cannot silently do nothing. When this convention was introduced it immediately caught six roles — `tailscale`, `prek`, `fastfetch`, `neovim`, `fonts` and `kubectl` — that were downloading things and never installing them.

Verification uses the bare command name rather than an absolute path, so a role does not care whether apt, an upstream `.deb` or uv provided the binary.

## Variable layering

| Location | Precedence | Contents |
| --- | --- | --- |
| `defaults/main.yml` | lowest | Anything a user might reasonably change |
| `group_vars/all.yml` | above defaults | Machine identity, `dotfiles_roles`, overrides |
| `vars/main.yml` | above group_vars | Invariants; overriding these would just break it |
| `vars/Ubuntu-<major>.yml` | above group_vars | Properties of the OS, not preferences |
| `-e` | highest | Escape hatch |

The trap worth documenting: `vars/` outranks `group_vars/`. Anything a user must be able to override belongs in `defaults/`, never `vars/`.

Variables are flat — `git_user_email`, not `git.email` — because a nested dict cannot be partially overridden. Setting `git: {email: ...}` in `host_vars` would silently wipe every other key under `git`.

## meta/main.yml always has empty dependencies

Role dependencies bypass `dotfiles_roles` selection and execute silently. Ordering is expressed once, in that list, where it can be read.

## The apt_repo helper

Five roles used to hand-roll "install deps, `apt_key`, `dpkg --print-architecture`, `apt_repository`", each slightly differently, and all five were broken or about to be — `apt-key` is gone in Ubuntu 24.04+.

`roles/apt_repo` replaces them, built on `deb822_repository`, whose `signed_by:` takes a URL and handles fetch and dearmor itself.

For repositories that lag a new Ubuntu release it sends a HEAD to the suite's `Release` file and falls back only when absent:

```yaml
apt_repo_suite: "{{ ansible_distribution_release }}"
apt_repo_suite_fallback: noble
```

A static codename map was rejected: it becomes a lie the moment the vendor catches up, and someone then has to notice and delete it. The probe self-heals. **No Ubuntu codename is hardcoded anywhere in the repository.**

## Enforcement

`scripts/check-structure` asserts all of the above mechanically — required files, orchestrator purity, one task-name prefix per role matching the role, no `apt_key`, no `--break-system-packages`, no unknown role in `dotfiles_roles`. It runs in CI, and it catches the exact mistakes already found here: a block named `Fastfetch | Install` inside the `kind` role, and one named `NVM | Install` inside `prek`.
