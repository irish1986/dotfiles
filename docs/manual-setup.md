# Manual setup

What `scripts/setup` does, done without Ansible: one block to paste per step, on a fresh Ubuntu 26.04 WSL distro, for the `home` or the `work` profile. For the automated route, see the README's [Quick start](../README.md#quick-start).

> **Snapshot.** Written against commit `f0e1387ff171bf293fdd163885096553c5b0a0e5`, and not kept in sync. Step 0 checks out that commit so the files the blocks copy match the versions they install. The roles and profiles are the source of truth (ADR [0003](adr/0003-data-driven-tools.md), [0004](adr/0004-pinned-versions-renovate.md)).

## How the blocks work

- Paste each block whole, in order. Each one writes its commands to `/tmp/step.sh` and runs them with bash, so it works the same from bash or zsh.
- A block stops at the first error and leaves your terminal open. Fix the cause and paste the same block again: every block is safe to re-run.
- A block ends with the checks the role's `verify.yml` makes, and prints `✓ <step> done` only when they pass.
- Steps 1 (network) and part of 7 apply to one profile only. The blocks decide that from the profile you give in step 0.

## Before you start

- Windows 11 with WSL 2.7.6 or later (`wsl --version` in PowerShell; `wsl --update` if older), and Windows Terminal.
- A GitHub account, and a browser to approve `gh auth login` in step 8.
- Work machines: the corporate CA exported from Windows as a PEM file, such as `C:\Users\<you>\corp-root-ca.crt`, and the proxy URL. If the proxy blocks the distro download itself, set it in Windows first.

From PowerShell, create the distro and set up its user when it asks:

```powershell
wsl --install Ubuntu-26.04 --name dotfiles
```

## 0. Bootstrap

Asks for the profile, your git identity and GitHub login (and the proxy and CA on work), and writes them to `~/manual-setup.env`, which every later block reads. On work it trusts the CA and points apt at the proxy before anything downloads. Then it clones the repository at the pinned commit.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
env_file=~/manual-setup.env
if [ -f "$env_file" ]; then . "$env_file"; fi
ask() { local reply; read -rp "$1 [$2]: " reply; printf '%s' "${reply:-$2}"; }

profile=$(ask 'Profile (home or work)' "${PROFILE:-home}")
case $profile in home | work) ;; *) echo "profile must be home or work" >&2; exit 1 ;; esac
name=$(ask 'Git name' "${GIT_NAME:-$(git config --global user.name || true)}")
email=$(ask 'Git email' "${GIT_EMAIL:-$(git config --global user.email || true)}")
login=$(ask 'GitHub login' "${GH_LOGIN:-}")
proxy='' no_proxy_list='' ca=''
if [ "$profile" = work ]; then
  proxy=$(ask 'Proxy URL, such as http://proxy.example.com:8080 (empty for none)' "${PROXY:-}")
  no_proxy_list=$(ask 'Hosts that skip the proxy' "${NO_PROXY_LIST:-localhost,127.0.0.1,::1}")
  ca=$(ask 'Corporate CA in PEM, such as /mnt/c/Users/you/corp-root-ca.crt (empty for none)' "${CA:-}")
fi
if [ -z "$name" ] || [ -z "$email" ] || [ -z "$login" ]; then
  echo "the git name, git email and GitHub login are all needed" >&2; exit 1
fi

{
  printf 'export PROFILE=%q GIT_NAME=%q GIT_EMAIL=%q GH_LOGIN=%q\n' "$profile" "$name" "$email" "$login"
  printf 'export PROXY=%q NO_PROXY_LIST=%q CA=%q\n' "$proxy" "$no_proxy_list" "$ca"
  cat << 'EOF'
export DOTFILES="$HOME/.dotfiles"
export HOST_NAME="$(hostname -s)"
export ARCH="$(dpkg --print-architecture)"
export CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
export WINHOME="$(wslpath -u "$(cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /d /c 'echo %USERPROFILE%' | tr -d '\r\n')")"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if [ -n "$PROXY" ]; then
  export http_proxy="$PROXY" https_proxy="$PROXY" no_proxy="$NO_PROXY_LIST"
  export HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY" NO_PROXY="$NO_PROXY_LIST"
fi
if [ -n "$CA" ]; then
  export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
fi

# put_block NAME top|bottom FILE MODE < content: write a marked block into FILE, replacing an earlier copy.
# The markers are the playbook's, so a later playbook run on this distro finds the block instead of adding another.
put_block() {
  local name=$1 where=$2 file=$3 mode=$4 body rest=''
  body=$(printf '# BEGIN ANSIBLE MANAGED BLOCK %s\n%s\n# END ANSIBLE MANAGED BLOCK %s' "$name" "$(cat)" "$name")
  if [ -f "$file" ]; then
    rest=$(sed "/^# BEGIN ANSIBLE MANAGED BLOCK $name\$/,/^# END ANSIBLE MANAGED BLOCK $name\$/d" "$file")
  fi
  if [ "$where" = top ]; then
    printf '%s\n' "$body" ${rest:+"$rest"} > "$file.new"
  else
    printf '%s\n' ${rest:+"$rest"} "$body" > "$file.new"
  fi
  mv "$file.new" "$file" && chmod "$mode" "$file"
}
EOF
} > "$env_file"
. "$env_file"
[ -d "$WINHOME" ] || { echo "could not find the Windows profile ($WINHOME)" >&2; exit 1; }

if [ -n "$CA" ]; then
  sudo install -d -m 0755 /usr/local/share/ca-certificates/dotfiles
  sudo install -m 0644 "$CA" "/usr/local/share/ca-certificates/dotfiles/$(basename "$CA" | sed -E 's/\.(pem|crt|cer)$//').crt"
  sudo update-ca-certificates --fresh
fi
if [ -n "$PROXY" ]; then
  printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "$PROXY" "$PROXY" | sudo tee /etc/apt/apt.conf.d/95dotfiles-proxy > /dev/null
fi

sudo apt-get update
sudo apt-get install -y ca-certificates curl git python3
[ -d "$DOTFILES/.git" ] || git clone https://github.com/irish1986/dotfiles.git "$DOTFILES"
git -C "$DOTFILES" switch -q --detach f0e1387ff171bf293fdd163885096553c5b0a0e5
git -C "$DOTFILES" remote set-url origin git@github.com:irish1986/dotfiles.git

echo "Windows profile: $WINHOME"
echo "✓ 0 bootstrap done"
STEP
bash /tmp/step.sh
```

## 1. Network (work only)

Replaces `roles/network`: the proxy and CA for every shell, the docker daemon and git. Step 0 already did apt and the CA. On home it does nothing.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env
if [ "$PROFILE" != work ]; then echo "✓ 1 network skipped (home)"; exit 0; fi

{
  if [ -n "$PROXY" ]; then
    printf 'export http_proxy="%s" https_proxy="%s" no_proxy="%s"\n' "$PROXY" "$PROXY" "$NO_PROXY_LIST"
    echo 'export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy" NO_PROXY="$no_proxy"'
  fi
  if [ -n "$CA" ]; then
    echo 'export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt" REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt" NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"'
  fi
} | put_block network top ~/.zshenv 0600

if [ -n "$PROXY" ]; then
  # Picked up when docker is installed in step 7.
  sudo install -d -m 0755 /etc/systemd/system/docker.service.d
  printf '[Service]\nEnvironment="HTTP_PROXY=%s"\nEnvironment="HTTPS_PROXY=%s"\nEnvironment="NO_PROXY=%s"\n' "$PROXY" "$PROXY" "$NO_PROXY_LIST" \
    | sudo tee /etc/systemd/system/docker.service.d/dotfiles-proxy.conf > /dev/null
  git config --file ~/.gitconfig http.proxy "$PROXY"
fi

# verify
if [ -n "$CA" ]; then ls "/etc/ssl/certs/$(basename "$CA" | sed -E 's/\.(pem|crt|cer)$//').pem"; fi
if [ -n "$PROXY" ]; then [ "$(git config --file ~/.gitconfig http.proxy)" = "$PROXY" ]; fi
echo "✓ 1 network done"
STEP
bash /tmp/step.sh
```

## 2. Update

Replaces `roles/update`: upgrade everything, and unattended upgrades with automatic reboots off, since WSL cannot reboot itself. From here on apt installs no recommended packages.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
sudo apt-get -y autoremove
sudo apt-get autoclean
sudo apt-get install -y unattended-upgrades

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
if [ -d /run/systemd/system ]; then
  sudo systemctl enable unattended-upgrades
  sudo systemctl restart unattended-upgrades
fi

# verify
held=$(apt-mark showhold)
if [ -n "$held" ]; then echo "held, so not upgraded: $held"; fi
[ -z "$(sudo dpkg --audit)" ]
echo "✓ 2 update done"
STEP
bash /tmp/step.sh
```

## 3. System

Replaces `roles/system`: base packages and the Hack Nerd Font files, which step 4 installs on Windows. On WSL, `wsl.conf` sets the hostname.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env

packages="apt-transport-https bind9-dnsutils ca-certificates curl git make nano wget"
sudo apt-get install -y $packages unzip

mkdir -p ~/.local/share/fonts
chmod 0755 ~/.local/share/fonts
if [ ! -f ~/.local/share/fonts/HackNerdFont-Regular.ttf ]; then
  curl -fsSLo /tmp/Hack.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Hack.zip
  unzip -o -q /tmp/Hack.zip -d ~/.local/share/fonts -x LICENSE LICENSE.txt README.md
  rm /tmp/Hack.zip
fi

# verify
for p in $packages; do dpkg-query -W -f='${Status}\n' "$p" | grep -q 'ok installed'; done
ls ~/.local/share/fonts/HackNerdFont-Regular.ttf
echo "✓ 3 system done"
STEP
bash /tmp/step.sh
```

## 4. WSL

Replaces `roles/wsl`, on both sides:

- In the distro: `wsl.conf` and the win32yank clipboard bridge.
- On Windows: the `.wslconfig` keys, the fonts installed for your Windows user, and the Windows Terminal settings.

`.wslconfig` gets `memory=48GB`, sized for a 64 GB workstation. On a smaller machine, run `export WSL_MEMORY=16GB` first, with the size you want. Every other key in the file is left alone, and a backup is kept as `.wslconfig.bak`.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env
cmd=/mnt/c/Windows/System32/cmd.exe
powershell=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
(cd /mnt/c && "$cmd" /c ver)   # interop works

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

# Clipboard bridge
mkdir -p ~/.local/bin ~/.local/opt/win32yank-0.1.1
if [ ! -f ~/.local/opt/win32yank-0.1.1/win32yank.exe ]; then
  curl -fsSLo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip
  unzip -o -q /tmp/win32yank.zip win32yank.exe -d ~/.local/opt/win32yank-0.1.1
  rm /tmp/win32yank.zip
fi
chmod 0755 ~/.local/opt/win32yank-0.1.1/win32yank.exe
ln -sfn ~/.local/opt/win32yank-0.1.1/win32yank.exe ~/.local/bin/win32yank.exe

# .wslconfig: processors is half the host's logical CPUs, rounded up.
host_cpus=$(cd /mnt/c && "$cmd" /d /c 'echo %NUMBER_OF_PROCESSORS%' | tr -d '\r\n')
wslconfig="$WINHOME/.wslconfig"
if [ -f "$wslconfig" ] && [ ! -f "$wslconfig.bak" ]; then cp "$wslconfig" "$wslconfig.bak"; fi
python3 - "$wslconfig" "${WSL_MEMORY:-48GB}" "$(( (host_cpus + 1) / 2 ))" << 'PY'
import re, sys
path, memory, processors = sys.argv[1:]
want = {
    'wsl2': [('memory', memory), ('processors', processors), ('swap', '8GB'), ('networkingMode', 'mirrored'),
             ('dnsTunneling', 'true'), ('firewall', 'true'), ('guiApplications', 'true'), ('nestedVirtualization', 'true')],
    'experimental': [('autoMemoryReclaim', 'gradual'), ('sparseVhd', 'true')],
}
try:
    lines = open(path, encoding='utf-8-sig').read().splitlines()
except FileNotFoundError:
    lines = []
for section, keys in want.items():
    for key, value in keys:
        start = next((i for i, line in enumerate(lines) if line.strip().lower() == f'[{section.lower()}]'), None)
        if start is None:
            if lines and lines[-1].strip():
                lines.append('')
            lines.append(f'[{section}]')
            start = len(lines) - 1
        end = next((i for i in range(start + 1, len(lines)) if lines[i].strip().startswith('[')), len(lines))
        hit = next((i for i in range(start + 1, end) if re.match(rf'\s*{key}\s*=', lines[i], re.I)), None)
        if hit is not None:
            lines[hit] = f'{key}={value}'
        else:
            last = max(i for i in range(start, end) if lines[i].strip())
            lines.insert(last + 1, f'{key}={value}')
open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
PY

# Fonts, for this Windows user only: copied into its font folder, then registered under HKCU.
fontdir="$WINHOME/AppData/Local/Microsoft/Windows/Fonts"
mkdir -p "$fontdir"
for f in ~/.local/share/fonts/*.ttf; do
  [ -e "$fontdir/${f##*/}" ] || cp "$f" "$fontdir/"
done
cat > /tmp/fonts.ps1 << 'PS1'
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore
$dest = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$reg = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
foreach ($f in Get-ChildItem -Path $dest -Filter 'Hack*NerdFont*.ttf') { $gt = New-Object Windows.Media.GlyphTypeface ([Uri]$f.FullName); $name = ((($gt.Win32FamilyNames.Values | Select-Object -First 1) + ' ' + ($gt.Win32FaceNames.Values | Select-Object -First 1)).Trim() -replace '\s+', ' ') + ' (TrueType)'; New-ItemProperty -Path $reg -Name $name -Value $f.FullName -PropertyType String -Force | Out-Null }
Write-Output 'fonts registered'

PS1
(cd /mnt/c && "$powershell" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command - < /tmp/fonts.ps1)
rm /tmp/fonts.ps1

# Windows Terminal: merged into the global settings and profiles.defaults; profiles.list, actions and themes are left alone.
python3 - "$WINHOME" << 'PY'
import json, os, sys
home = sys.argv[1]
candidates = [
    f'{home}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json',
    f'{home}/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json',
    f'{home}/AppData/Local/Microsoft/Windows Terminal/settings.json',
]
path = next((p for p in candidates if os.path.exists(p)), None)
if path is None:
    print('warning: no Windows Terminal settings.json found; open Terminal once and paste this step again')
    sys.exit(0)
try:
    current = json.load(open(path, encoding='utf-8-sig'))
except ValueError:
    print(f'warning: {path} has comments or is not plain JSON; merge the settings by hand (see roles/wsl/defaults/main.yml)')
    sys.exit(0)
want = {
    'copyOnSelect': False, 'copyFormatting': 'none', 'firstWindowPreference': 'defaultProfile',
    'launchMode': 'focus', 'showTabsInTitlebar': False, 'centerOnLaunch': False,
    'initialCols': 95, 'initialRows': 53, 'initialPosition': '0,0',
    'profiles': {'defaults': {'colorScheme': 'Campbell', 'opacity': 85, 'padding': '2', 'scrollbarState': 'hidden',
                              'font': {'face': 'Hack Nerd Font', 'size': 12}}},
}
def merge(into, new):
    for key, value in new.items():
        if isinstance(value, dict) and isinstance(into.get(key), dict):
            merge(into[key], value)
        else:
            into[key] = value
    return into
merged = merge(json.loads(json.dumps(current)), want)
if merged != current:
    open(path, 'w', encoding='utf-8').write(json.dumps(merged, indent=4, ensure_ascii=False) + '\n')
print('Terminal settings up to date')
PY

# verify
[ -f /etc/wsl.conf ]
ls "$fontdir/HackNerdFont-Regular.ttf"
saved=$(win32yank.exe -o --lf || true)
printf probe | win32yank.exe -i --crlf
[ "$(win32yank.exe -o --lf)" = probe ]
printf '%s' "$saved" | win32yank.exe -i --crlf
echo "✓ 4 wsl done"
echo
echo "Now restart WSL: close every Windows Terminal window, then in PowerShell run"
echo "    wsl --shutdown"
echo "    wsl -d ${WSL_DISTRO_NAME:-dotfiles}"
STEP
bash /tmp/step.sh
```

**Restart now.** Close every Windows Terminal window, run `wsl --shutdown` in PowerShell, then reopen the distro. `wsl.conf` applies when the distro starts and `.wslconfig` when the WSL VM boots, and Windows Terminal only sees the new fonts after a restart. Step 5 refuses to run until the restart has happened.

## 5. Zsh

Replaces `roles/zsh`: packages, oh-my-zsh, the pinned plugins and the shell dotfiles. It starts by checking that the restart after step 4 happened.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env
mounts=$(grep ' /mnt/c ' /proc/mounts || true)
if [ ! -d /run/systemd/system ] || [[ $mounts != *metadata* ]]; then
  echo "WSL is not running with the new wsl.conf yet: run 'wsl --shutdown' in PowerShell, reopen, and paste this again" >&2; exit 1
fi

sudo apt-get install -y bat eza fzf git jq trash-cli tree whois yq zoxide zsh

if [ ! -d ~/.oh-my-zsh ]; then
  curl -fsSLo /tmp/omz-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
  ZSH="$HOME/.oh-my-zsh" sh /tmp/omz-install.sh --unattended --keep-zshrc
  rm /tmp/omz-install.sh
fi

# plugin NAME themes|plugins REPO TAG-OR-COMMIT
plugin() {
  local dest="$HOME/.oh-my-zsh/custom/$2/$1"
  if [ -d "$dest" ]; then return 0; fi
  if [[ $4 =~ ^[0-9a-f]{40}$ ]]; then
    git clone -q "$3" "$dest" && git -C "$dest" checkout -q "$4"
  else
    git clone -q --depth 1 --branch "$4" "$3" "$dest"
  fi
}
plugin powerlevel10k themes https://github.com/romkatv/powerlevel10k.git v1.20.0
plugin you-should-use plugins https://github.com/MichaelAquilina/zsh-you-should-use.git 1.9.0
plugin zsh-autosuggestions plugins https://github.com/zsh-users/zsh-autosuggestions v0.7.1
plugin zsh-bat plugins https://github.com/fdellwing/zsh-bat.git 467337613c1c220c0d01d69b19d2892935f43e9f
plugin zsh-completions plugins https://github.com/zsh-users/zsh-completions 67921bc12502c1e7b0f156533fbac2cb51f6943d
plugin zsh-eza plugins https://github.com/z-shell/zsh-eza 79484190e314c0e5bdbcc3e610300589606c45f0
plugin zsh-syntax-highlighting plugins https://github.com/zsh-users/zsh-syntax-highlighting.git 0.8.0

# Skip Ubuntu's system-wide compinit; oh-my-zsh runs its own. About a second off every startup.
echo 'skip_global_compinit=1' | put_block zsh top ~/.zshenv 0600

install -m 0644 "$DOTFILES/roles/zsh/files/.zshrc" ~/.zshrc
install -m 0644 "$DOTFILES/roles/zsh/files/.zshaliases" ~/.zshaliases
install -m 0644 "$DOTFILES/roles/zsh/files/.zshfunc" ~/.zshfunc
install -m 0644 "$DOTFILES/roles/zsh/files/.p10k" ~/.p10k.zsh

# verify
zsh --version
ls ~/.zshrc ~/.zshaliases ~/.zshfunc ~/.p10k.zsh ~/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme > /dev/null
echo "✓ 5 zsh done"
STEP
bash /tmp/step.sh
```

## 6. User

Replaces `roles/user`: passwordless sudo, the sudo and docker groups, zsh as the login shell, and the home directory modes. The groups and the shell apply to new terminals.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env

sudo grep -q '^%sudo' /etc/sudoers
printf '%s\n' '# Managed by the dotfiles playbook (roles/user). Do not edit.' "$USER ALL=(ALL) NOPASSWD: ALL" > /tmp/90-dotfiles
sudo visudo -cf /tmp/90-dotfiles
sudo install -m 0440 -o root -g root /tmp/90-dotfiles /etc/sudoers.d/90-dotfiles
rm /tmp/90-dotfiles

sudo groupadd -f docker
sudo usermod -aG sudo,docker "$USER"
sudo chsh -s /usr/bin/zsh "$USER"

mkdir -p ~/.cache ~/.config ~/.local/bin ~/.local/share ~/.local/state
chmod 0700 ~/.cache ~/.local/share ~/.local/state
chmod 0755 ~/.config ~/.local/bin

# verify
sudo visudo -cf /etc/sudoers.d/90-dotfiles
[ "$(getent passwd "$USER" | cut -d: -f7)" = /usr/bin/zsh ]
[[ " $(id -nG "$USER") " == *" docker "* && " $(id -nG "$USER") " == *" sudo "* ]]
echo "✓ 6 user done"
STEP
bash /tmp/step.sh
```

## 7. Tools

Replaces `roles/tools`, the longest step: apt packages and repositories, release downloads, installer scripts, node, the agent skills, the gh extension, Python, config files and the docker daemon. Home and work differ here:

- Home adds `build-essential`, Tailscale, Infisical, Hugo, rustup, Claude Code and Claude Code's copy of the skills and instructions.
- Work adds snyk.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env
home() { [ "$PROFILE" = home ]; }

apt_packages="btop libssl-dev python3 python3-pip python3-venv"
if home; then apt_packages="$apt_packages build-essential"; fi
sudo apt-get install -y $apt_packages

# Apt repositories, as deb822 .sources files. Docker and Tailscale publish one suite per Ubuntu release and can lag a new one: fall back to noble then.
suite() { if [ "$(curl -s -o /dev/null -w '%{http_code}' -I "$1/dists/$CODENAME/Release")" = 200 ]; then echo "$CODENAME"; else echo noble; fi; }
# repo NAME URI SUITE COMPONENT KEY-URL KEY-EXTENSION
repo() {
  curl -fsSL "$5" | sudo tee "/etc/apt/keyrings/$1.$6" > /dev/null
  printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: %s\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/%s.%s\n' \
    "$2" "$3" "$4" "$ARCH" "$1" "$6" | sudo tee "/etc/apt/sources.list.d/$1.sources" > /dev/null
}
sudo install -d -m 0755 /etc/apt/keyrings
repo github-cli https://cli.github.com/packages stable main https://cli.github.com/packages/githubcli-archive-keyring.gpg gpg
s=$(suite https://download.docker.com/linux/ubuntu)
repo docker https://download.docker.com/linux/ubuntu "$s" stable https://download.docker.com/linux/ubuntu/gpg asc
repo_packages="gh containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin"
if home; then
  s=$(suite https://pkgs.tailscale.com/stable/ubuntu)
  repo tailscale https://pkgs.tailscale.com/stable/ubuntu "$s" main "https://pkgs.tailscale.com/stable/ubuntu/$s.asc" asc
  repo infisical https://artifacts-cli.infisical.com/deb stable main https://artifacts-cli.infisical.com/infisical.gpg asc
  repo_packages="$repo_packages tailscale infisical"
fi
sudo apt-get update
sudo apt-get install -y $repo_packages

# .deb releases
deb() { curl -fsSLo "/tmp/$1.deb" "$2" && sudo apt-get install -y "/tmp/$1.deb" && rm "/tmp/$1.deb"; }
deb fastfetch "https://github.com/fastfetch-cli/fastfetch/releases/download/2.68.1/fastfetch-linux-$ARCH.deb"
if home; then deb hugo "https://github.com/gohugoio/hugo/releases/download/v0.166.0/hugo_extended_0.166.0_linux-$ARCH.deb"; fi

# Single binaries, checked against their published sha256
bin() {
  curl -fsSLo "/tmp/$1" "$2"
  echo "$(curl -fsSL "$2.sha256" | awk '{print $1}')  /tmp/$1" | sha256sum -c -
  sudo install -m 0755 -o root -g root "/tmp/$1" "/usr/local/bin/$1" && rm "/tmp/$1"
}
bin tokenuse "https://github.com/russmckendrick/tokenuse/releases/download/v1.2.6/tokenuse-linux-$ARCH"
if [ "$PROFILE" = work ]; then bin snyk https://github.com/snyk/cli/releases/download/v1.1307.4/snyk-linux; fi

# Installer scripts, run once; each tool updates itself afterwards.
[ -x ~/.local/bin/uv ] || curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
# PROFILE=/dev/null keeps nvm out of ~/.zshrc, which loads it itself.
[ -s ~/.nvm/nvm.sh ] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | env NVM_DIR="$HOME/.nvm" PROFILE=/dev/null bash
[ -x ~/.local/bin/copilot ] || curl -fsSL https://gh.io/copilot-install | bash
if home; then
  [ -x ~/.cargo/bin/rustup ] || curl -fsSL https://sh.rustup.rs | env CARGO_HOME="$HOME/.cargo" RUSTUP_HOME="$HOME/.rustup" \
    sh -s -- -y --no-modify-path --profile default --default-toolchain stable
  [ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash
fi

# Node 24 from nvm. nvm.sh does not run under set -eu.
export NVM_DIR="$HOME/.nvm"
set +eu
. "$NVM_DIR/nvm.sh"
nvm install --no-progress 24 && nvm alias default 24
rc=$?
set -eu
[ "$rc" = 0 ]

# The same agent skills in every agent CLI (ADR 0015).
agents="github-copilot"
if home; then agents="$agents claude-code"; fi
export DISABLE_TELEMETRY=1 NPM_CONFIG_UPDATE_NOTIFIER=false
npx --yes skills@1.7.0 add herdrdev/herdr --skill herdr --global --agent $agents --yes
npx --yes skills@1.7.0 add mattpocock/skills --skill '*' --global --agent $agents --yes
npx --yes skills@1.7.0 add github/gh-stack --skill gh-stack --global --agent $agents --yes

[ -d ~/.local/share/gh/extensions/gh-stack ] || gh extension install github/gh-stack

uv python install 3.14 --default
uv tool install --force prek==0.5.3

# Config files
F="$DOTFILES/roles/tools/files"
install -D -m 0644 "$F/btop/btop.conf" ~/.config/btop/btop.conf
install -D -m 0644 "$F/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc
install -D -m 0644 "$F/npm/npmrc" ~/.config/npm/npmrc
mkdir -p ~/.copilot && chmod 0700 ~/.copilot
install -m 0644 "$F/agents/instructions.md" ~/.copilot/copilot-instructions.md
if home; then
  mkdir -p ~/.claude && chmod 0700 ~/.claude
  install -m 0644 "$F/agents/instructions.md" ~/.claude/CLAUDE.md
fi

# Docker daemon
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
sudo dockerd --validate --config-file /tmp/daemon.json
sudo install -D -m 0644 -o root -g root /tmp/daemon.json /etc/docker/daemon.json
rm /tmp/daemon.json
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

# verify
gh --version && docker --version && fastfetch --version && tokenuse --version
uv --version && copilot --version && prek --version && gh stack --version
node --version && npm --version
ls ~/.agents/skills/herdr/SKILL.md ~/.agents/skills/gh-stack/SKILL.md
if home; then
  tailscale version && infisical --version && hugo version && claude --version
  cargo --version && rustc --version
  ls ~/.claude/skills/herdr/SKILL.md ~/.claude/skills/gh-stack/SKILL.md
else
  snyk --version
fi
echo "✓ 7 tools done"
STEP
bash /tmp/step.sh
```

## 8. SSH

Replaces `roles/ssh`. WSL gets no SSH server. The step:

- writes hardened client defaults into `~/.ssh/config`;
- imports your GitHub keys into `authorized_keys`;
- copies in the machine key, the one in your Windows profile, and creates it there first if it is missing ([ADR 0011](adr/0011-copy-the-windows-ssh-key.md));
- registers the key on GitHub to authenticate and to sign.

It stops once for `gh auth login`: open the URL it prints and enter the code.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env

sudo apt-get install -y openssh-client
mkdir -p ~/.ssh/sockets
chmod 0700 ~/.ssh ~/.ssh/sockets

put_block defaults bottom ~/.ssh/config 0600 << EOF
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
EOF
ssh -G -F ~/.ssh/config example.com > /dev/null

touch ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
curl -fsSL "https://github.com/$GH_LOGIN.keys" | while read -r key; do
  grep -qxF "$key" ~/.ssh/authorized_keys || echo "$key" >> ~/.ssh/authorized_keys
done

# The machine key lives in the Windows profile; created there, without a passphrase, if missing.
if [ ! -f "$WINHOME/.ssh/id_ed25519" ]; then
  mkdir -p "$WINHOME/.ssh"
  (cd /mnt/c && /mnt/c/Windows/System32/OpenSSH/ssh-keygen.exe -q -t ed25519 -N "" \
    -C "$USER@$HOST_NAME" -f "$(wslpath -w "$WINHOME/.ssh")\\id_ed25519")
fi
install -m 0600 "$WINHOME/.ssh/id_ed25519" ~/.ssh/id_ed25519
install -m 0644 "$WINHOME/.ssh/id_ed25519.pub" ~/.ssh/id_ed25519.pub

# gh needs two extra scopes to manage SSH keys. --skip-ssh-key: the key is added below, as two types.
scopes=admin:public_key,admin:ssh_signing_key
if ! gh auth status --hostname github.com > /dev/null 2>&1; then
  gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key --scopes "$scopes"
elif [[ $(gh auth status --hostname github.com 2>&1) != *admin:ssh_signing_key* ]]; then
  gh auth refresh --hostname github.com --scopes "$scopes"
fi
pub=$(cut -d' ' -f1,2 ~/.ssh/id_ed25519.pub)
auth_keys=$(gh api user/keys --jq '.[].key')
signing_keys=$(gh api user/ssh_signing_keys --jq '.[].key')
grep -qxF "$pub" <<< "$auth_keys" || gh ssh-key add ~/.ssh/id_ed25519.pub --title "$USER@$HOST_NAME" --type authentication
grep -qxF "$pub" <<< "$signing_keys" || gh ssh-key add ~/.ssh/id_ed25519.pub --title "$USER@$HOST_NAME" --type signing

# verify
ssh -V
[ "$(stat -c %a ~/.ssh)" = 700 ] && [ "$(stat -c %a ~/.ssh/config)" = 600 ] && [ "$(stat -c %a ~/.ssh/id_ed25519)" = 600 ]
[[ $(ssh -G example.com) == *$'\n'"ciphers chacha20-poly1305@openssh.com,"* ]]
[ "$pub" = "$(cut -d' ' -f1,2 "$WINHOME/.ssh/id_ed25519.pub")" ]
out=$(ssh -n -T -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true)
echo "$out"
grep -q 'successfully authenticated' <<< "$out"
echo "✓ 8 ssh done"
STEP
bash /tmp/step.sh
```

## 9. Git

Replaces `roles/git`: packages, the global gitignore, `~/git/<login>`, your identity, SSH commit signing, and gh's settings and aliases. It ends by making a signed commit in a throwaway repository.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env

sudo apt-get install -y git git-lfs git-filter-repo
install -m 0644 "$DOTFILES/roles/git/files/.gitignore" ~/.gitignore
mkdir -p ~/git/"$GH_LOGIN"
chmod 0700 ~/git/"$GH_LOGIN"

# Who may sign as you: your email and the machine key.
echo "$GIT_EMAIL $(cat ~/.ssh/id_ed25519.pub)" | put_block "$GIT_EMAIL" bottom ~/.ssh/allowed_signers 0644

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

gh config set git_protocol ssh
gh config set editor 'code --wait'
gh config set prompt enabled
gh alias set co 'pr checkout' --clobber
gh alias set pv 'pr view' --clobber
gh alias set st status --clobber

# verify
git --version
[ "$(git config --file ~/.gitconfig user.email)" = "$GIT_EMAIL" ]
d=$(mktemp -d)
git -C "$d" init -q
git -C "$d" commit -q --allow-empty -m probe
sig=$(git -C "$d" log --show-signature -1)
rm -rf "$d"
grep -qi 'good "git" signature' <<< "$sig"
echo "✓ 9 git done"
STEP
bash /tmp/step.sh
```

## 10. Secrets

Replaces `roles/secrets` as it runs when the local file names no secrets source: it installs the sync script and nothing more. On home, the Infisical CLI came with step 7. Wiring a source and targets is in the README's **Secrets** section.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env

install -D -m 0755 "$DOTFILES/roles/secrets/files/dotfiles-secrets" ~/.local/bin/dotfiles-secrets

# verify
dotfiles-secrets path
if [ "$PROFILE" = home ]; then infisical --version; fi
echo "✓ 10 secrets done"
STEP
bash /tmp/step.sh
```

## 11. Herdr

Replaces `roles/herdr`: the binary, its config, a systemd user service (enabled, not started), the integrations for the agent CLIs that are installed, and the autostart that takes every new login shell into herdr.

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
. ~/manual-setup.env

installed=$(~/.local/bin/herdr --version 2> /dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
if [ "$installed" != 0.9.1 ]; then
  curl -fsSLo ~/.local/bin/herdr "https://github.com/herdrdev/herdr/releases/download/v0.9.1/herdr-linux-$(uname -m)"
fi
chmod 0755 ~/.local/bin/herdr
install -D -m 0644 "$DOTFILES/roles/herdr/files/config.toml" ~/.config/herdr/config.toml
install -m 0755 "$DOTFILES/roles/herdr/files/herdr-worktree" ~/.local/bin/herdr-worktree

# The user manager keeps running with no session open, so the herdr server outlives the terminal.
sudo loginctl enable-linger "$USER"
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
user_manager=no
if [ -e "/run/user/$(id -u)/systemd/private" ]; then user_manager=yes; fi
if [ "$user_manager" = yes ]; then
  systemctl --user daemon-reload
  systemctl --user enable herdr
else
  echo "warning: the systemd user manager is not running (a known WSL first-boot issue); run 'wsl --terminate ${WSL_DISTRO_NAME:-dotfiles}' in PowerShell, reopen, and paste this again"
fi

for agent in claude copilot; do
  if [ -x ~/.local/bin/$agent ]; then herdr integration install "$agent"; fi
done

put_block herdr bottom ~/.zshenv 0600 << EOF
[[ ":\$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:\$PATH"
if [[ -o login && -o interactive && -z \$HERDR_ENV \\
      && \${HERDR_AUTOSTART:-1} != 0 && -x $HOME/.local/bin/herdr ]]; then
  exec $HOME/.local/bin/herdr
fi
EOF

# verify
herdr --version
HERDR_CONFIG_PATH=~/.config/herdr/config.toml herdr config check
grep -q "exec $HOME/.local/bin/herdr" ~/.zshenv
zsh -n ~/.zshenv
if [ "$user_manager" = yes ]; then [ "$(systemctl --user is-enabled herdr)" = enabled ]; fi
echo "✓ 11 herdr done"
STEP
bash /tmp/step.sh
```

## 12. First login

Open a new tab on the distro in Windows Terminal. It should start zsh, go straight into herdr, and show the powerlevel10k prompt in the Hack Nerd Font with no broken glyphs. In that tab:

```bash
cat > /tmp/step.sh << 'STEP'
set -euo pipefail
[[ " $(id -nG) " == *" docker "* ]]
docker run --rm hello-world
fastfetch
rm -f /tmp/step.sh
echo "✓ 12 first login done: the machine is set up"
STEP
bash /tmp/step.sh
```

`~/manual-setup.env` can go now, or stay for re-running a block later.
