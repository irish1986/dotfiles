# Troubleshooting

## A run reports success but did nothing

This was possible before and is not any more, but the symptom is worth knowing.
An earlier `main.yml` wrapped every role in a `rescue:` that caught all failures
and printed a debug message, then a `post_task` reported "Playbook ran without any
issue". Combined with a missing `inventory/group_vars/all.yml` — which is
gitignored, so a fresh clone never had one — every role raised on undefined
variables and the run still looked green.

If you see a suspiciously short run, check the file exists:

```bash
ls -l ~/.dotfiles/inventory/group_vars/all.yml
```

`scripts/setup` seeds it. To recreate it by hand:

```bash
cp ~/.dotfiles/docs/examples/group_vars-all.yml ~/.dotfiles/inventory/group_vars/all.yml
```

## apt fails on a lock

```text
Could not get lock /var/lib/dpkg/lock-frontend
```

`unattended-upgrades` holds the dpkg lock, most often shortly after boot. The
`update` role enables it, so run N arms the daemon that inconveniences run N+1.
Every apt call in `scripts/setup` waits up to ten minutes for the lock; if it
still fails, wait for the daemon to finish and re-run.

## Two sudo prompts

Expected on a first run: one for the script's own package installs, one for
Ansible. They cannot share a ticket — the local connection plugin runs
`sudo -H -S -n` with no controlling tty, and sudo's `tty_tickets` keys the
timestamp to the terminal.

After one successful run the `system` role grants passwordless sudo and both
prompts stop.

## Windows Terminal ignores the settings

Check the file that was actually written:

```bash
ls -l "/mnt/c/Users/$USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
```

The `LocalState/` segment is the one that matters. An earlier version wrote to the
package root, which Terminal never reads.

If the run reported *"Could not parse ... it may contain JSONC comments"*, the
merge was skipped and nothing was written — Terminal accepts comments in
`settings.json` but the merge needs strict JSON. Remove the comments or let the
UI rewrite the file.

## Fonts render as boxes or mojibake

The Powerlevel10k prompt needs a Nerd Font on the **Windows** side, since that is
what draws the terminal. Check it is registered, not merely present on disk:

```powershell
Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" |
  Select-Object -Property *Hack*
```

A file in `%LOCALAPPDATA%\Microsoft\Windows\Fonts` with no registry value is
invisible to Windows.

If the run reported fonts as `LOCKED`, they are open in a running process and were
left at their existing version. Close Windows Terminal and any editor using them,
then re-run:

```bash
scripts/setup --tags wsl
```

## wsl.conf or .wslconfig changes do nothing

They apply on restart only. From PowerShell or CMD — not inside the distro:

```powershell
wsl --shutdown
```

## git refuses to touch a plugin directory

```text
fatal: detected dubious ownership in repository at ...
```

Something created those files as root. An earlier `ansible.cfg` enabled `become`
globally, which also applied to fact gathering, so `ansible_user_dir` resolved to
`/root` and tasks writing to the user's home produced root-owned files. Repair
the ownership:

```bash
sudo chown -R "$USER:$USER" ~/.oh-my-zsh ~/.gitconfig ~/.gitignore ~/.zsh*
```

Be specific about the paths. Do not blanket-chown `$HOME` — container bind mounts
and Docker artefacts under it are root-owned by design.

## Reading the log

Run logs live in `~/.local/state/dotfiles/`, ten at a time, and are kept when a
run fails:

```bash
ls -t ~/.local/state/dotfiles/setup-*.log | head -1 | xargs less
```

On failure the last 40 lines print automatically, along with the command that
failed.

## Isolating a role

```bash
scripts/setup --tags docker -v
scripts/setup --check --diff --tags docker
scripts/setup -- -e '{"dotfiles_roles":["docker"]}'
```

The last form evaluates nothing but that role.
