# Playbook

## main.yml

The play is deliberately small: resolve facts, validate the role selection, then
loop over `dotfiles_roles` in order.

```yaml
- name: DotFiles
  hosts: localhost
  connection: local
  gather_facts: true

  pre_tasks:
    - ansible.builtin.import_tasks: pre_tasks/facts.yml
    - ansible.builtin.import_tasks: pre_tasks/validate.yml

  tasks:
    - name: "DotFiles | Role: {{ dotfiles_role }}"
      ansible.builtin.include_role:
        name: "{{ dotfiles_role }}"
        apply:
          tags: ["{{ dotfiles_role }}"]
      loop: "{{ dotfiles_roles }}"
```

There is no `rescue:`. An earlier version had one that caught every failure from
every role, printed a debug message, and then let a `post_task` report
"Playbook ran without any issue" — so the play was structurally incapable of
reporting failure. `PLAY RECAP` and the `profile_tasks` callback report the
truth instead.

## Environment facts

`pre_tasks/facts.yml` resolves the environment into typed facts. Roles consume
these rather than re-deriving them.

| Fact | Meaning |
| --- | --- |
| `dotfiles_user`, `dotfiles_home` | Target user and home, trailing slash stripped |
| `dotfiles_is_wsl` | Real boolean, from `ansible_virtualization_type` or the kernel string |
| `dotfiles_wsl_version` | 1 or 2 |
| `dotfiles_has_systemd` | `ansible_service_mgr == 'systemd'` |
| `dotfiles_in_container` | Container, excluding WSL |
| `dotfiles_can_reboot` | False on WSL and in containers |
| `dotfiles_dpkg_architecture` | Computed once, not per role |
| `dotfiles_github_headers` | Adds a token when `GH_TOKEN` is set |

Three of these replace conditions that did not express what they meant:

- **`dotfiles_has_systemd`** gates services. WSL2 with `systemd=true` *does* want
  Docker enabled; a CI container does not. The previous `not is_wsl` covered
  neither case.
- **`dotfiles_can_reboot`** gates reboots, which terminate a WSL distro.
- **`dotfiles_in_container`** excludes WSL, which also reports virtualization
  type `container`.

WSL detection deliberately uses two signals. `ansible_virtualization_type`
reports `wsl` on some ansible-core versions and `container` on others — 2.16.3
reports `container` on WSL2 — so the kernel string is the dependable one.

## The interpreter pin

`inventory/hosts.yml` declares `localhost` explicitly with
`ansible_python_interpreter: /usr/bin/python3`.

This is a security measure, not tidiness. `uv python install --default` puts a
user-owned interpreter on `PATH` ahead of `/usr/bin/python3`, and Ansible's
discovery follows it — so every `become: true` task would have root executing an
interpreter the login user can modify. `interpreter_python` in `ansible.cfg`
cannot fix it: the *implicit* localhost gets `ansible_python_interpreter` set to
the controller's own interpreter at a precedence neither `ansible.cfg` nor
`group_vars` can beat. Declaring the host explicitly is what makes the pin stick.

## become

`become` is deliberately **not** enabled globally. When it is, it also applies to
the implicit `gather_facts` task, so `ansible_user_dir` resolves to `/root` and
every task writing to the user's home creates root-owned files. Roles declare
`become: true` on the individual tasks that need it, and only in their `install`
phase.

Fact caching is off for the same reason: it persisted those `/root` facts for the
whole cache timeout.
