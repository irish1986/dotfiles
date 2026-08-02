# Secrets

Secrets come from [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/) through the `bitwarden.secrets` lookup, and are written into `~/.zshenv` by the `zsh` role. Nothing secret is stored in this repository.

This is **off by default**. Enable it in `inventory/group_vars/all.yml`:

```yaml
zsh_manage_secrets: true
```

## The access token

```bash
export BWS_ACCESS_TOKEN="<your-bws-access-token>"
```

For something more durable than a shell export, `scripts/setup` sources `~/.config/dotfiles/setup.env` if it exists, and warns when it is not mode `0600`:

```bash
install -d -m 0700 ~/.config/dotfiles
printf 'BWS_ACCESS_TOKEN=%s\n' "<token>" > ~/.config/dotfiles/setup.env
chmod 0600 ~/.config/dotfiles/setup.env
```

The script warns if a secret-bearing role is enabled and no token is set, rather than failing part-way through the run.

## Why the SDK placement matters

`bitwarden.secrets.lookup` is a **controller-side** lookup: it runs in the process executing `ansible-playbook`, so `bitwarden_sdk` has to be importable by *that* interpreter.

This is the part that used to be broken. The old `pre_tasks/vault.yml` installed `bitwarden-sdk` as its own pipx application, which puts it in a virtualenv Ansible cannot import from — so the lookup could never have worked. `scripts/setup` now injects it into the `ansible-core` environment instead:

```bash
uv tool install --with bitwarden-sdk 'ansible-core>=2.16,<2.24'
```

The `ansible_tools` role asserts the import succeeds, so a broken secret path fails visibly rather than at first use.

## Which secrets

Defined in `roles/zsh/defaults/main.yml` as a list of name and Secrets Manager UUID pairs. The UUIDs identify vault items; they are not the secrets themselves, which is why they can live in the repository. The rendered block is written with `no_log: true` so the values never reach the Ansible log.
