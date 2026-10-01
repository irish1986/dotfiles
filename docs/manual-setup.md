# Manual setup

Everything `scripts/setup` does for the `home` profile, done by hand on a fresh Ubuntu 26.04 WSL distro, with a timing log so the two can be compared. The `work` profile's additions are in [Appendix A](#appendix-a--work-profile); the automated run to compare against is in [Appendix B](#appendix-b--the-automated-run).

> **Snapshot.** Written against commit `f0e1387ff171bf293fdd163885096553c5b0a0e5`, and not kept in sync. Versions are hardcoded as they were at that commit; the roles and profiles are the source of truth (ADR [0003](adr/0003-data-driven-tools.md), [0004](adr/0004-pinned-versions-renovate.md)). Step 0 checks out that commit so the files you copy match the text.

## How to use this

- Sections follow the playbook's role order (`dotfiles_role_order` in [`main.yml`](../main.yml)). Each one names the role it replaces, gives the commands, and ends with the check that role's `verify.yml` runs.
- Each section starts with `mark start <id>` and ends with `mark end <id>`. `mark` appends a timestamp to `~/manual-setup-timing.log`, and the [summary](#summary) turns the log into minutes.
- Copy files from the checkout; do not retype them. Templates are given here already rendered, with the defaults the playbook would use.
- Do not take a break inside a section. If you have to, note it in the summary table and subtract it.
- Not reproduced, because a fresh machine has nothing for them to do: the clean-up lists (`tools_remove_apt`, `tools_remove_paths`, `tools_remove_agent_plugins`), the pre-deb822 docker clean-up, the `--rotate-ssh-key` path, and the multi-distro `wsl_global_owner` handling.

## Before you start (not timed)

- Windows 11 with WSL 2.7.6 or later (`wsl --version` in PowerShell; `wsl --update` if older), and Windows Terminal.
- A GitHub account, and a browser to approve `gh auth login`.
- Your git name and email, and your GitHub login.
- Optional: an SSH key at `%USERPROFILE%\.ssh\id_ed25519`. Step 7 creates one if it is missing ([ADR 0011](adr/0011-copy-the-windows-ssh-key.md)).

Create the throwaway distro from PowerShell, and set up its user when it asks:

```powershell
wsl --list --online                                  # confirm the name: Ubuntu-26.04
wsl --install Ubuntu-26.04 --name dotfiles-manual
```

When you are done with it: `wsl --unregister dotfiles-manual`.

## 0. Bootstrap

Replaces the first half of `scripts/setup`: base packages, the checkout, and the values the local file would hold. Start the clock as soon as you are at the distro's first prompt.

Write the session file. Edit the first three lines before sourcing it:

```bash
cat > ~/manual-setup.env << 'EOF'
export GIT_NAME='Your Name'
export GIT_EMAIL='you@example.com'
export GH_LOGIN='your-github-login'
export HOST_NAME="$(hostname -s)"
export ARCH="$(dpkg --print-architecture)"
export CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
export WINHOME="$(wslpath -u "$(cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /d /c 'echo %USERPROFILE%' | tr -d '\r\n')")"
export DOTFILES="$HOME/.dotfiles"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
mark() { printf '%s %s %s %s\n' "$(date +%s)" "$(date +%T)" "$1" "$2" | tee -a "$HOME/manual-setup-timing.log"; }
EOF
nano ~/manual-setup.env
. ~/manual-setup.env && mark start 0-bootstrap
```

Every later section starts by sourcing this file again, so it survives restarts and the switch to zsh.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git

git clone https://github.com/irish1986/dotfiles.git "$DOTFILES"
git -C "$DOTFILES" switch --detach f0e1387ff171bf293fdd163885096553c5b0a0e5
git -C "$DOTFILES" remote set-url origin git@github.com:irish1986/dotfiles.git
```

Check: `echo "$WINHOME"` prints your Windows profile, such as `/mnt/c/Users/you`, and `ls "$WINHOME"` lists it.

```bash
mark end 0-bootstrap
```

## 1. Update

Replaces `roles/update`: upgrade everything, then unattended upgrades.

```bash
. ~/manual-setup.env && mark start 1-update

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
sudo apt-get -y autoremove && sudo apt-get autoclean
sudo apt-get install -y unattended-upgrades
```

The three apt configuration files. From here on apt installs no recommended packages, as it does in the playbook's runs:

```bash
sudo tee /etc/apt/apt.conf.d/2norecommends > /dev/null << 'EOF'
APT::Get::Install-Recommends "false";
APT::Get::Install-Suggests "false";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null << 'EOF'
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Update-Package-Lists "1";
EOF

# WSL cannot be rebooted from inside, so automatic reboots are off.
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
    "${distro_id}:${distro_codename}";
    "${distro_id}ESM:${distro_codename}-infra-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
EOF

sudo systemctl enable unattended-upgrades && sudo systemctl restart unattended-upgrades
```

If `/var/run/reboot-required` exists, the restart at the end of step 3 takes care of it.

Verify: both commands print nothing.

```bash
apt-mark showhold
sudo dpkg --audit
mark end 1-update
```

## 2. System

Replaces `roles/system`: base packages and the Nerd Font files. On WSL the hostname belongs to `wsl.conf` (step 3), and there is no guest agent.

```bash
. ~/manual-setup.env && mark start 2-system

sudo apt-get install -y apt-transport-https bind9-dnsutils ca-certificates curl git make nano wget unzip

mkdir -p ~/.local/share/fonts && chmod 0755 ~/.local/share/fonts
curl -fsSLo /tmp/Hack.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Hack.zip
unzip -o /tmp/Hack.zip -d ~/.local/share/fonts -x LICENSE LICENSE.txt README.md
rm /tmp/Hack.zip
```

Verify:

```bash
dpkg-query -W -f='${Package} ${Status}\n' apt-transport-https bind9-dnsutils ca-certificates curl git make nano wget
ls ~/.local/share/fonts/HackNerdFont-Regular.ttf
mark end 2-system
```

## 3. WSL

Replaces `roles/wsl`: `wsl.conf`, the clipboard bridge, and the Windows-side state: `.wslconfig`, the Windows font install, and Windows Terminal settings.

```bash
. ~/manual-setup.env && mark start 3-wsl
```

### Interop

Every Windows-side step below needs it:

```bash
(cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /c ver)
```

### wsl.conf

```bash
sudo tee /etc/wsl.conf > /dev/null << EOF
[boot]
systemd = true

[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[interop]
enabled = true
appendWindowsPath = true

[network]
hostname = $HOST_NAME
generateHosts = true
generateResolvConf = true

[user]
default = $USER
EOF
cat /etc/wsl.conf
```

### Clipboard bridge

```bash
mkdir -p ~/.local/bin ~/.local/opt/win32yank-0.1.1
curl -fsSLo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip
unzip -o /tmp/win32yank.zip win32yank.exe -d ~/.local/opt/win32yank-0.1.1
chmod 0755 ~/.local/opt/win32yank-0.1.1/win32yank.exe
ln -sfn ~/.local/opt/win32yank-0.1.1/win32yank.exe ~/.local/bin/win32yank.exe
rm /tmp/win32yank.zip
```

### .wslconfig

The playbook sets these keys one by one and leaves every other key in the file alone. `processors` is half the host's logical CPUs, rounded up:

```bash
host_cpus=$(cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /d /c 'echo %NUMBER_OF_PROCESSORS%' | tr -d '\r')
echo "processors=$(( (host_cpus + 1) / 2 ))"
cp "$WINHOME/.wslconfig" "$WINHOME/.wslconfig.bak" 2> /dev/null || true
notepad.exe "$(wslpath -w "$WINHOME/.wslconfig")"
```

Make the file contain these keys. Add any that are missing, change any that differ, keep everything else, and save. Notepad offers to create the file if it does not exist.

```ini
[wsl2]
memory=48GB
processors=<the number printed above>
swap=8GB
networkingMode=mirrored
dnsTunneling=true
firewall=true
guiApplications=true
nestedVirtualization=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
```

`48GB` is the default, sized for a 64 GB workstation. Use whatever `wsl_config_memory` your local file would set.

### Windows fonts

A per-user install: no administrator rights needed. It must come before the Terminal settings, which name the font.

```bash
mkdir -p "$WINHOME/Downloads/HackNerdFont"
cp ~/.local/share/fonts/*.ttf "$WINHOME/Downloads/HackNerdFont/"
explorer.exe "$(wslpath -w "$WINHOME/Downloads/HackNerdFont")" || true
```

In the Explorer window, select every `.ttf` file, right-click, and choose **Install**, not "Install for all users". Then delete the folder.

### Windows Terminal

Open Terminal's **Settings** and select **Open JSON file** at the bottom left. Merge these keys into the top level of the file, and into `profiles.defaults`. Leave `profiles.list`, `actions`, `schemes` and `themes` alone:

```json
{
    "copyOnSelect": false,
    "copyFormatting": "none",
    "firstWindowPreference": "defaultProfile",
    "launchMode": "focus",
    "showTabsInTitlebar": false,
    "centerOnLaunch": false,
    "initialCols": 95,
    "initialRows": 53,
    "initialPosition": "0,0",
    "profiles": {
        "defaults": {
            "colorScheme": "Campbell",
            "opacity": 85,
            "padding": "2",
            "scrollbarState": "hidden",
            "font": {
                "face": "Hack Nerd Font",
                "size": 12
            }
        }
    }
}
```

Save. The playbook does not change the default profile.

### Restart

`wsl.conf` applies when the distro restarts, and `.wslconfig` when the whole WSL VM restarts. Fonts need a fresh Terminal. Close every Windows Terminal window, then from PowerShell:

```powershell
wsl --shutdown
wsl -d dotfiles-manual
```

Verify, back in the distro:

```bash
. ~/manual-setup.env
cat /etc/wsl.conf > /dev/null && echo "wsl.conf present"
hostname                                   # = HOST_NAME
grep ' /mnt/c ' /proc/mounts               # options include metadata,umask=22,fmask=11
systemctl is-system-running                # running or degraded, not "offline"
printf probe | win32yank.exe -i --crlf && win32yank.exe -o --lf; echo   # prints: probe
mark end 3-wsl
```

## 4. Zsh

Replaces `roles/zsh`: packages, oh-my-zsh, pinned plugins and the shell dotfiles.

```bash
. ~/manual-setup.env && mark start 4-zsh

sudo apt-get install -y bat eza fzf git jq trash-cli tree whois yq zoxide zsh

curl -fsSLo /tmp/omz-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
ZSH="$HOME/.oh-my-zsh" sh /tmp/omz-install.sh --unattended --keep-zshrc
rm /tmp/omz-install.sh
```

The plugins, each at its pinned version. Tags clone shallow; commit pins need a full clone:

```bash
C=~/.oh-my-zsh/custom
git clone -q --depth 1 --branch v1.20.0 https://github.com/romkatv/powerlevel10k.git "$C/themes/powerlevel10k"
git clone -q --depth 1 --branch 1.9.0 https://github.com/MichaelAquilina/zsh-you-should-use.git "$C/plugins/you-should-use"
git clone -q --depth 1 --branch v0.7.1 https://github.com/zsh-users/zsh-autosuggestions "$C/plugins/zsh-autosuggestions"
git clone -q --depth 1 --branch 0.8.0 https://github.com/zsh-users/zsh-syntax-highlighting.git "$C/plugins/zsh-syntax-highlighting"
git clone -q https://github.com/fdellwing/zsh-bat.git "$C/plugins/zsh-bat" \
  && git -C "$C/plugins/zsh-bat" checkout -q 467337613c1c220c0d01d69b19d2892935f43e9f
git clone -q https://github.com/zsh-users/zsh-completions "$C/plugins/zsh-completions" \
  && git -C "$C/plugins/zsh-completions" checkout -q 67921bc12502c1e7b0f156533fbac2cb51f6943d
git clone -q https://github.com/z-shell/zsh-eza "$C/plugins/zsh-eza" \
  && git -C "$C/plugins/zsh-eza" checkout -q 79484190e314c0e5bdbcc3e610300589606c45f0
```

`~/.zshenv` skips Ubuntu's system-wide `compinit`, which costs about a second of every startup. The block goes at the top of the file. The markers are the playbook's, so a later playbook run on this distro recognises the block instead of adding a second copy.

```bash
{ printf '%s\n' '# BEGIN ANSIBLE MANAGED BLOCK zsh' 'skip_global_compinit=1' '# END ANSIBLE MANAGED BLOCK zsh'
  cat ~/.zshenv 2> /dev/null; } > ~/.zshenv.new && mv ~/.zshenv.new ~/.zshenv && chmod 0600 ~/.zshenv
```

The dotfiles. `.p10k` is renamed to `.p10k.zsh`:

```bash
install -m 0644 "$DOTFILES/roles/zsh/files/.zshrc" ~/.zshrc
install -m 0644 "$DOTFILES/roles/zsh/files/.zshaliases" ~/.zshaliases
install -m 0644 "$DOTFILES/roles/zsh/files/.zshfunc" ~/.zshfunc
install -m 0644 "$DOTFILES/roles/zsh/files/.p10k" ~/.p10k.zsh
```

Verify:

```bash
zsh --version
ls ~/.zshrc ~/.zshaliases ~/.zshfunc ~/.p10k.zsh
ls ~/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme
mark end 4-zsh
```

## 5. User

Replaces `roles/user`: passwordless sudo, groups, login shell and home directory modes.

```bash
. ~/manual-setup.env && mark start 5-user

sudo grep -q '^%sudo' /etc/sudoers && echo "%sudo rule present"   # Ubuntu ships it

printf '%s\n' '# Managed by the dotfiles playbook (roles/user). Do not edit.' "$USER ALL=(ALL) NOPASSWD: ALL" > /tmp/90-dotfiles
sudo visudo -cf /tmp/90-dotfiles && sudo install -m 0440 -o root -g root /tmp/90-dotfiles /etc/sudoers.d/90-dotfiles
rm /tmp/90-dotfiles

# docker is created now so that joining it works before docker is installed.
sudo groupadd -f docker
sudo usermod -aG sudo,docker "$USER"

sudo chsh -s /usr/bin/zsh "$USER"

mkdir -p ~/.cache ~/.config ~/.local/bin ~/.local/share ~/.local/state
chmod 0700 ~/.cache ~/.local/share ~/.local/state
chmod 0755 ~/.config ~/.local/bin
```

Verify:

```bash
sudo visudo -cf /etc/sudoers.d/90-dotfiles
getent passwd "$USER" | cut -d: -f7        # /usr/bin/zsh
id -nG "$USER"                             # includes sudo and docker
stat -c '%a %n' ~/.cache ~/.config ~/.local/bin ~/.local/share ~/.local/state
mark end 5-user
```

The new groups and login shell apply to new terminals. You can stay in this one.

## 6. Tools

Replaces `roles/tools`, the biggest step: apt packages and repositories, release downloads, installer scripts, node, agent skills, the gh extension, Python tools, config files and docker.

```bash
. ~/manual-setup.env && mark start 6-tools
```

### Apt packages

```bash
sudo apt-get install -y btop libssl-dev python3 python3-pip python3-venv build-essential
```

### Apt repositories

Each repository is a deb822 `.sources` file with its own key. Docker and Tailscale publish one suite per Ubuntu release, so the playbook first checks that this release's suite exists and falls back to `noble` if it does not. Both had a `resolute` suite when this was written; check before you start:

```bash
for u in https://download.docker.com/linux/ubuntu https://pkgs.tailscale.com/stable/ubuntu; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -I "$u/dists/$CODENAME/Release")" "$u"
done   # 200 for both: carry on. Anything else: run CODENAME=noble before the next block
```

```bash
sudo install -d -m 0755 /etc/apt/keyrings

# gh. The key is binary.
sudo curl -fsSLo /etc/apt/keyrings/github-cli.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
sudo tee /etc/apt/sources.list.d/github-cli.sources > /dev/null << EOF
Types: deb
URIs: https://cli.github.com/packages
Suites: stable
Components: main
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/github-cli.gpg
EOF

# docker. The key is ASCII-armored.
sudo curl -fsSLo /etc/apt/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $CODENAME
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# tailscale. One key per release.
sudo curl -fsSLo /etc/apt/keyrings/tailscale.asc "https://pkgs.tailscale.com/stable/ubuntu/$CODENAME.asc"
sudo tee /etc/apt/sources.list.d/tailscale.sources > /dev/null << EOF
Types: deb
URIs: https://pkgs.tailscale.com/stable/ubuntu
Suites: $CODENAME
Components: main
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/tailscale.asc
EOF

# infisical. Used by the secrets role.
sudo curl -fsSLo /etc/apt/keyrings/infisical.asc https://artifacts-cli.infisical.com/infisical.gpg
sudo tee /etc/apt/sources.list.d/infisical.sources > /dev/null << EOF
Types: deb
URIs: https://artifacts-cli.infisical.com/deb
Suites: stable
Components: main
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/infisical.asc
EOF

sudo apt-get update
sudo apt-get install -y gh containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin tailscale infisical
```

### Release downloads

```bash
# .deb releases
curl -fsSLo /tmp/fastfetch.deb "https://github.com/fastfetch-cli/fastfetch/releases/download/2.68.1/fastfetch-linux-$ARCH.deb"
curl -fsSLo /tmp/hugo.deb "https://github.com/gohugoio/hugo/releases/download/v0.166.0/hugo_extended_0.166.0_linux-$ARCH.deb"
sudo apt-get install -y /tmp/fastfetch.deb /tmp/hugo.deb
rm /tmp/fastfetch.deb /tmp/hugo.deb

# A single binary, checked against its published sha256
url="https://github.com/russmckendrick/tokenuse/releases/download/v1.2.6/tokenuse-linux-$ARCH"
curl -fsSLo /tmp/tokenuse "$url"
echo "$(curl -fsSL "$url.sha256" | awk '{print $1}')  /tmp/tokenuse" | sha256sum -c -
sudo install -m 0755 -o root -g root /tmp/tokenuse /usr/local/bin/tokenuse && rm /tmp/tokenuse
```

### Installer scripts

Each one runs once. After that, the tool updates itself.

```bash
# uv
curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh

# nvm. PROFILE=/dev/null keeps it out of ~/.zshrc, which already loads it.
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | env NVM_DIR="$HOME/.nvm" PROFILE=/dev/null bash

# GitHub Copilot CLI
curl -fsSL https://gh.io/copilot-install | bash

# rustup (home)
curl -fsSL https://sh.rustup.rs | env CARGO_HOME="$HOME/.cargo" RUSTUP_HOME="$HOME/.rustup" \
  sh -s -- -y --no-modify-path --profile default --default-toolchain stable

# Claude Code (home)
curl -fsSL https://claude.ai/install.sh | bash
```

### Node and the agent skills

```bash
. ~/.nvm/nvm.sh
nvm install --no-progress 24
nvm alias default 24

# The same skills for Copilot and Claude Code (ADR 0015). Each --yes skips a different prompt: npx's, then the skills CLI's.
export DISABLE_TELEMETRY=1 NPM_CONFIG_UPDATE_NOTIFIER=false
npx --yes skills@1.7.0 add herdrdev/herdr --skill herdr --global --agent github-copilot claude-code --yes
npx --yes skills@1.7.0 add mattpocock/skills --skill '*' --global --agent github-copilot claude-code --yes
npx --yes skills@1.7.0 add github/gh-stack --skill gh-stack --global --agent github-copilot claude-code --yes
```

### gh extension and Python

```bash
gh extension install github/gh-stack

uv python install 3.14 --default
uv tool install --force prek==0.5.3
```

### Config files

```bash
F="$DOTFILES/roles/tools/files"
install -D -m 0644 "$F/btop/btop.conf" ~/.config/btop/btop.conf
install -D -m 0644 "$F/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc
install -D -m 0644 "$F/npm/npmrc" ~/.config/npm/npmrc
mkdir -p ~/.copilot ~/.claude && chmod 0700 ~/.copilot ~/.claude
install -m 0644 "$F/agents/instructions.md" ~/.copilot/copilot-instructions.md
install -m 0644 "$F/agents/instructions.md" ~/.claude/CLAUDE.md
```

### Docker daemon

```bash
cat > /tmp/daemon.json << 'EOF'
{
  "default-address-pools": [
    {
      "base": "172.10.0.0/16",
      "size": 24
    }
  ],
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
EOF
sudo dockerd --validate --config-file /tmp/daemon.json \
  && sudo install -D -m 0644 -o root -g root /tmp/daemon.json /etc/docker/daemon.json
rm /tmp/daemon.json
sudo systemctl enable docker && sudo systemctl restart docker
```

Verify: every command must succeed.

```bash
gh --version && docker --version && tailscale version && infisical --version
fastfetch --version && hugo version && tokenuse --version
uv --version && copilot --version && claude --version
(. ~/.nvm/nvm.sh && nvm --version && node --version && npm --version)
cargo --version && rustc --version
prek --version && gh stack --version
ls ~/.agents/skills/*/SKILL.md ~/.claude/skills/*/SKILL.md
mark end 6-tools
```

## 7. SSH

Replaces `roles/ssh`: client config, authorized keys, the machine key (made on Windows and copied in, [ADR 0011](adr/0011-copy-the-windows-ssh-key.md)), and registering it on GitHub. WSL gets no SSH server.

```bash
. ~/manual-setup.env && mark start 7-ssh

sudo apt-get install -y openssh-client
mkdir -p ~/.ssh/sockets && chmod 0700 ~/.ssh ~/.ssh/sockets
```

### Client config

A `Host *` block of hardened defaults at the end of `~/.ssh/config`:

```bash
cat >> ~/.ssh/config << EOF
# BEGIN ANSIBLE MANAGED BLOCK defaults
Host *
  KexAlgorithms curve25519-sha256@libssh.org,curve25519-sha256,diffie-hellman-group-exchange-sha256
  Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr
  MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256
  StrictHostKeyChecking ask
  HashKnownHosts yes
  VerifyHostKeyDNS ask
  UpdateHostKeys yes
  PubkeyAuthentication yes
  IdentitiesOnly yes
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  AddKeysToAgent yes
  ForwardAgent no
  ForwardX11 no
  ForwardX11Trusted no
  PermitLocalCommand no
  ServerAliveInterval 60
  ServerAliveCountMax 3
  Compression no
  ControlMaster auto
  ControlPersist 10m
  IdentityFile $HOME/.ssh/id_ed25519
  ControlPath $HOME/.ssh/sockets/%C
# END ANSIBLE MANAGED BLOCK defaults
EOF
chmod 0600 ~/.ssh/config
ssh -G -F ~/.ssh/config example.com > /dev/null && echo "config parses"
```

### Authorized keys

The keys published on your GitHub profile:

```bash
curl -fsSL "https://github.com/$GH_LOGIN.keys" >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
```

### The key

If Windows has no key yet, create it there, without a passphrase, as the playbook does:

```bash
if [ ! -f "$WINHOME/.ssh/id_ed25519" ]; then
  mkdir -p "$WINHOME/.ssh"
  (cd /mnt/c && /mnt/c/Windows/System32/OpenSSH/ssh-keygen.exe -q -t ed25519 -N "" \
    -C "$USER@$HOST_NAME" -f "$(wslpath -w "$WINHOME/.ssh")\\id_ed25519")
fi

install -m 0600 "$WINHOME/.ssh/id_ed25519" ~/.ssh/id_ed25519
install -m 0644 "$WINHOME/.ssh/id_ed25519.pub" ~/.ssh/id_ed25519.pub
```

### GitHub

Log gh in with the two scopes it needs to manage SSH keys. `--skip-ssh-key` stops gh from uploading a key of its own; the next step does that:

```bash
gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key \
  --scopes admin:public_key,admin:ssh_signing_key
```

Register the key twice, once to authenticate and once to sign, skipping either one that GitHub already has:

```bash
pub=$(cut -d' ' -f1,2 ~/.ssh/id_ed25519.pub)
gh api user/keys --jq '.[].key' | grep -qxF "$pub" \
  || gh ssh-key add ~/.ssh/id_ed25519.pub --title "$USER@$HOST_NAME" --type authentication
gh api user/ssh_signing_keys --jq '.[].key' | grep -qxF "$pub" \
  || gh ssh-key add ~/.ssh/id_ed25519.pub --title "$USER@$HOST_NAME" --type signing
```

Verify:

```bash
ssh -V
stat -c '%a %n' ~/.ssh ~/.ssh/config ~/.ssh/id_ed25519   # 700, 600, 600
ssh -G example.com | grep -i '^ciphers'                  # the list above
diff <(cut -d' ' -f1,2 "$WINHOME/.ssh/id_ed25519.pub") <(cut -d' ' -f1,2 ~/.ssh/id_ed25519.pub) && echo "matches the Windows key"
ssh -T git@github.com                                    # answer yes to the host key; "Hi <login>! You've successfully authenticated"
mark end 7-ssh
```

## 8. Git

Replaces `roles/git`: packages, global gitignore, identity, SSH commit signing, and gh's config and aliases.

```bash
. ~/manual-setup.env && mark start 8-git

sudo apt-get install -y git git-lfs git-filter-repo
install -m 0644 "$DOTFILES/roles/git/files/.gitignore" ~/.gitignore
mkdir -p ~/git/"$GH_LOGIN" && chmod 0700 ~/git/"$GH_LOGIN"

# Who may sign: your email and the machine key.
printf '%s\n' "# BEGIN ANSIBLE MANAGED BLOCK $GIT_EMAIL" "$GIT_EMAIL $(cat ~/.ssh/id_ed25519.pub)" "# END ANSIBLE MANAGED BLOCK $GIT_EMAIL" >> ~/.ssh/allowed_signers
chmod 0644 ~/.ssh/allowed_signers
```

The git configuration, in `~/.gitconfig`:

```bash
g() { git config --file ~/.gitconfig "$@"; }
g advice.diverging false
g branch.sort -committerdate
g color.ui auto
g column.ui auto
g commit.gpgsign true
g commit.verbose true
g core.autocrlf false
g core.editor 'code --wait'
g diff.algorithm histogram
g diff.colorMoved zebra
g fetch.all true
g fetch.prune true
g fetch.pruneTags true
g fetch.writeCommitGraph true
g gpg.format ssh
g help.autocorrect prompt
g init.defaultBranch main
g log.abbrevCommit true
g pull.rebase true
g push.autoSetupRemote true
g push.default simple
g push.followTags true
g rebase.autoStash true
g rerere.autoupdate true
g rerere.enabled true
g status.short true
g tag.gpgsign true
g tag.sort version:refname
g core.excludesfile "$HOME/.gitignore"
g gpg.ssh.allowedSignersFile "$HOME/.ssh/allowed_signers"
g user.email "$GIT_EMAIL"
g user.name "$GIT_NAME"
g user.signingkey "$HOME/.ssh/id_ed25519.pub"
```

gh:

```bash
gh config set git_protocol ssh
gh config set editor 'code --wait'
gh config set prompt enabled
gh alias set co 'pr checkout' --clobber
gh alias set pv 'pr view' --clobber
gh alias set st status --clobber
```

Verify. The last line makes a signed commit in a throwaway repository:

```bash
git --version
git config --file ~/.gitconfig user.email                # = GIT_EMAIL
d=$(mktemp -d) && git -C "$d" init -q && git -C "$d" commit -q --allow-empty -m probe \
  && git -C "$d" log --show-signature -1 | grep -i 'good "git" signature'; rm -rf "$d"
mark end 8-git
```

## 9. Secrets

Replaces `roles/secrets` as it runs when the local file names no secrets source: it installs the sync script and nothing more. The Infisical CLI came with step 6. Wiring a source and targets is left out on purpose; README's **Secrets** section covers it.

```bash
. ~/manual-setup.env && mark start 9-secrets

install -m 0755 "$DOTFILES/roles/secrets/files/dotfiles-secrets" ~/.local/bin/dotfiles-secrets
```

Verify:

```bash
dotfiles-secrets path
infisical --version
mark end 9-secrets
```

## 10. Herdr

Replaces `roles/herdr`: the binary, its config, a systemd user service, the agent integrations, and the autostart that execs every new login shell into herdr.

```bash
. ~/manual-setup.env && mark start 10-herdr

curl -fsSLo ~/.local/bin/herdr "https://github.com/herdrdev/herdr/releases/download/v0.9.1/herdr-linux-$(uname -m)"
chmod 0755 ~/.local/bin/herdr

install -D -m 0644 "$DOTFILES/roles/herdr/files/config.toml" ~/.config/herdr/config.toml
install -m 0755 "$DOTFILES/roles/herdr/files/herdr-worktree" ~/.local/bin/herdr-worktree

# Keep the user manager running with no session open, so the herdr server outlives the terminal.
sudo loginctl enable-linger "$USER"
```

The user service, enabled but not started, as the playbook leaves it:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/herdr.service << EOF
[Unit]
Description=herdr terminal workspace server
Documentation=https://herdr.dev/docs/session-state/
After=default.target

[Service]
Type=simple
ExecStart=$HOME/.local/bin/herdr server
ExecStop=$HOME/.local/bin/herdr server stop
Environment=HERDR_CONFIG_PATH=$HOME/.config/herdr/config.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable herdr
```

The agent integrations:

```bash
herdr integration status
herdr integration install claude
herdr integration install copilot
```

The autostart, at the end of `~/.zshenv`:

```bash
cat >> ~/.zshenv << EOF
# BEGIN ANSIBLE MANAGED BLOCK herdr
[[ ":\$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:\$PATH"
if [[ -o login && -o interactive && -z \$HERDR_ENV \\
      && \${HERDR_AUTOSTART:-1} != 0 && -x $HOME/.local/bin/herdr ]]; then
  exec $HOME/.local/bin/herdr
fi
# END ANSIBLE MANAGED BLOCK herdr
EOF
cat ~/.zshenv
```

Verify:

```bash
herdr --version
HERDR_CONFIG_PATH=~/.config/herdr/config.toml herdr config check
grep -c 'ANSIBLE MANAGED BLOCK herdr' ~/.zshenv          # 2
systemctl --user is-enabled herdr                        # enabled
mark end 10-herdr
```

## 11. First login

The machine is done when a new terminal works. Open a new tab on the distro in Windows Terminal (or `wsl -d dotfiles-manual` from PowerShell). It should start zsh, enter herdr, and show the powerlevel10k prompt in the Hack Nerd Font with no broken glyphs. Inside it:

```bash
. ~/manual-setup.env && mark start 11-login
id -nG | grep -w docker && docker run --rm hello-world
fastfetch
mark end 11-login
```

If something is broken here, fix it and leave the fix inside the timed section: the automated run has to pass the same test.

## Summary

Turn the log into minutes per section:

```bash
awk '$3=="start"{s[$4]=$1} $3=="end"{printf "%-12s %6.1f min\n", $4, ($1-s[$4])/60; t+=$1-s[$4]} END{printf "%-12s %6.1f min\n", "total", t/60}' ~/manual-setup-timing.log
```

Then fill in:

| Section | Minutes | Hands-on or waiting? | Notes (mistakes, lookups, breaks) |
| --- | --- | --- | --- |
| 0 Bootstrap | | | |
| 1 Update | | | |
| 2 System | | | |
| 3 WSL | | | |
| 4 Zsh | | | |
| 5 User | | | |
| 6 Tools | | | |
| 7 SSH | | | |
| 8 Git | | | |
| 9 Secrets | | | |
| 10 Herdr | | | |
| 11 First login | | | |
| **Manual total** | | | |
| **Automated total** ([B](#appendix-b--the-automated-run)) | | | |

"Hands-on" is time spent reading and typing; "waiting" is downloads and installs. A run where you sat watching apt counts as waiting. The automated run turns most hands-on time into waiting, and that difference is what you are measuring.

## Appendix A — work profile

What [`profiles/work.yml`](../profiles/work.yml) changes compared with home. Time it on its own distro (`--name dotfiles-work`), following the main steps with these changes, and log it as `A-network` plus the step rows it touches.

### Leave out the home-only parts

- Step 6: `build-essential`; the tailscale and infisical repositories and packages; hugo; rustup; Claude Code; `~/.claude/CLAUDE.md`. Install the skills with `--agent github-copilot` only.
- Step 9: `infisical --version` in the check.
- Step 10: `herdr integration install claude`.

### Before step 0

Behind the proxy, the bootstrap needs the proxy and the CA before anything downloads:

```bash
export https_proxy=http://proxy.example.com:8080 http_proxy=http://proxy.example.com:8080
sudo cp /mnt/c/Users/<you>/corp-root-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates
```

### Network, before step 1

Replaces `roles/network`, which runs first. Use your real values in place of the placeholders:

```bash
. ~/manual-setup.env && mark start A-network
PROXY=http://proxy.example.com:8080
NO_PROXY_LIST=localhost,127.0.0.1,::1
CA=/mnt/c/Users/<you>/corp-root-ca.crt     # PEM

# The CA, under its own directory, with .crt as update-ca-certificates requires.
sudo install -d -m 0755 /usr/local/share/ca-certificates/dotfiles
sudo install -m 0644 "$CA" "/usr/local/share/ca-certificates/dotfiles/$(basename "${CA%.*}").crt"
sudo update-ca-certificates --fresh

# Every shell: the proxy and the CA bundle. At the top of ~/.zshenv.
{ cat << EOF
# BEGIN ANSIBLE MANAGED BLOCK network
export http_proxy="$PROXY" https_proxy="$PROXY" no_proxy="$NO_PROXY_LIST"
export HTTP_PROXY="\$http_proxy" HTTPS_PROXY="\$https_proxy" NO_PROXY="\$no_proxy"
export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt" REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt" NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
# END ANSIBLE MANAGED BLOCK network
EOF
  cat ~/.zshenv 2> /dev/null; } > ~/.zshenv.new && mv ~/.zshenv.new ~/.zshenv && chmod 0600 ~/.zshenv

# apt
printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "$PROXY" "$PROXY" \
  | sudo tee /etc/apt/apt.conf.d/95dotfiles-proxy > /dev/null

# The docker daemon. The drop-in can go in before docker is installed.
sudo install -d -m 0755 /etc/systemd/system/docker.service.d
printf '[Service]\nEnvironment="HTTP_PROXY=%s"\nEnvironment="HTTPS_PROXY=%s"\nEnvironment="NO_PROXY=%s"\n' "$PROXY" "$PROXY" "$NO_PROXY_LIST" \
  | sudo tee /etc/systemd/system/docker.service.d/dotfiles-proxy.conf > /dev/null
sudo systemctl daemon-reload

# git
git config --file ~/.gitconfig http.proxy "$PROXY"
```

Also add `export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` and the two proxy variables to `~/manual-setup.env`. Until zsh takes over, they are what keeps the bash session's curl, npx and uv going through the proxy.

Verify:

```bash
ls "/etc/ssl/certs/$(basename "${CA%.*}").pem"
git config --file ~/.gitconfig http.proxy                # = PROXY
mark end A-network
```

### Snyk, in step 6

After the other release downloads. amd64 only:

```bash
url=https://github.com/snyk/cli/releases/download/v1.1307.4/snyk-linux
curl -fsSLo /tmp/snyk "$url"
echo "$(curl -fsSL "$url.sha256" | awk '{print $1}')  /tmp/snyk" | sha256sum -c -
sudo install -m 0755 -o root -g root /tmp/snyk /usr/local/bin/snyk && rm /tmp/snyk
snyk --version
```

## Appendix B — the automated run

The same machine from `scripts/setup`, on a second fresh distro, pinned to the same commit.

Windows-side state is shared between distros: `.wslconfig`, the fonts, the Terminal settings, the Windows SSH key and the GitHub key registration are already done by the manual run. The automated run finds them in place and skips them, so it is a few seconds faster than it would be on a really fresh machine. That bias is small next to the time those steps took by hand. For a strict comparison, undo them before this run: restore `.wslconfig.bak`, uninstall the Hack Nerd Font in **Settings > Personalization > Fonts**, and revert `settings.json`.

From PowerShell:

```powershell
wsl --install Ubuntu-26.04 --name dotfiles-auto
```

In the new distro, start the clock and run:

```bash
date +%T | tee ~/auto-start
git clone https://github.com/irish1986/dotfiles.git ~/.dotfiles
git -C ~/.dotfiles switch --detach f0e1387ff171bf293fdd163885096553c5b0a0e5
ANSIBLE_CALLBACKS_ENABLED=ansible.posix.profile_tasks ~/.dotfiles/scripts/setup --no-pull --profile home
```

It asks for your git name, email and GitHub login, then the sudo password, then **Proceed? [y/N]**. At the end, `profile_tasks` prints the slowest tasks and the run's total time. Then do what the run's messages ask:

1. `wsl --shutdown` from PowerShell, since `wsl.conf` and `.wslconfig` changed, and reopen with `wsl -d dotfiles-auto`. Restart Windows Terminal for the fonts.
2. Log gh in and grant the key scopes. The first run skipped the GitHub key because gh was not logged in yet:

   ```bash
   gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key \
     --scopes admin:public_key,admin:ssh_signing_key
   ```

3. Re-run, to finish what needed systemd or gh:

   ```bash
   ANSIBLE_CALLBACKS_ENABLED=ansible.posix.profile_tasks ~/.dotfiles/scripts/setup --no-pull --yes
   ```

4. Do the [first login](#11-first-login) check in a new tab, then stop the clock:

   ```bash
   echo "start $(cat ~/auto-start)  end $(date +%T)"
   ```

Record the wall-clock time from start to finish, restarts and prompts included, as **Automated total**. Note separately how long you were actually needed: the prompts, the restart, and `gh auth login`. That is the automated run's hands-on time.
