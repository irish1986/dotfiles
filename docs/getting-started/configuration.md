# Configuration

All machine configuration lives in one file, `inventory/group_vars/all.yml`. It
is gitignored, because it holds identity: your username, email and hostname.
`scripts/setup` creates it from
[`docs/examples/group_vars-all.yml`](https://github.com/irish1986/dotfiles/blob/main/docs/examples/group_vars-all.yml)
on a fresh clone. To reset it:

```bash
cp ~/.dotfiles/docs/examples/group_vars-all.yml ~/.dotfiles/inventory/group_vars/all.yml
```

Every key is listed in the [variables reference](../reference/variables.md).

## Choosing roles

`dotfiles_roles` is the decision about what this machine gets. It is an ordered
list, and order matters:

```yaml
dotfiles_roles:
  - update   # apt upgrade first, so everything below installs current
  - system   # sudoers and base packages
  - fonts    # before wsl: the Windows font install stages from ~/.local/share/fonts
  - wsl      # before zsh: .p10k.zsh renders as mojibake without a Nerd Font
  - zsh
  - git
  - ssh
  - python   # provides uv, which ansible_tools and prek depend on
  - nvm
  - docker
  - tmux
  - btop
  - fastfetch
  - neovim
```

Commented-out entries in the example are the opt-in roles. Uncomment to enable.

A name that does not match a directory under `roles/` fails the run immediately,
rather than part-way through.

## Tags versus the role list

They do different jobs, and it is worth being precise about which:

- **`dotfiles_roles`** is *what this machine gets*. Persistent, per-machine.
- **`--tags`** is *what to run right now*. A filter over that list, not an
  alternative to it.

```bash
scripts/setup --tags docker          # just docker
scripts/setup --tags k8s             # helm, kubectl, fluxcd, if enabled
scripts/setup --tags configure       # every role's config phase, no installs
scripts/setup --skip-tags update     # everything except the apt upgrade
```

Each role also carries a phase tag — `install`, `configure` or `verify` — and a
group tag such as `base`, `dev`, `shell`, `k8s`, `sec`, `iac` or `net`. The tags
for a given role are listed on its [role page](../roles/index.md).

To run one role and evaluate nothing else at all:

```bash
scripts/setup -- -e '{"dotfiles_roles":["docker"]}'
```

## Overriding role variables

Role defaults live in `roles/<role>/defaults/main.yml` and can be overridden in
`all.yml`. Variables are flat, not nested:

```yaml
git_user_email: you@example.com
fonts_nerd_fonts:
  - Hack
  - FiraCode
docker_data_root: ""   # empty means Docker's default, /var/lib/docker
```

Flat rather than nested for a specific reason: a nested dict cannot be partially
overridden. Setting `git: {email: ...}` in `host_vars` would silently wipe
`git.name`, `git.user` and `git.signing_key`.
