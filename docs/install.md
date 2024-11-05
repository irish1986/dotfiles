# Install

This repo is build with automation and fast execution as a key principal.  Although, sometimes it makes sense to setup your workstation manually.  Here how to manually setup and install my `.dotfiles` configuration.  This guide is really a simplified version and does not include all tasks and steps automated.

## Setup Windows Terminal

> [!NOTE]
> Windows Terminal requires Windows 10 2004 (build 19041) or later

Install the [Windows Terminal from the Microsoft Store](store-install-link).  This allows you to always be on the latest version when we release new builds with automatic upgrades.

## Setup additionals fonts

Nerd Fonts patches developer targeted fonts with a high number of glyphs (icons). Specifically to add a high number of extra glyphs from popular `iconic fonts`.  This setup

Download your prefered fonts from [Nerd Fonts Downloads](https://www.nerdfonts.com/font-downloads); my favorite is [Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Hack.zip).

Navigate to `Settings => Personalisation => Fonts` and install the downloaded fonts.

Open `Windows Terminal`, navigate to `Default => Apperance => Font Face` and select your custom fonts to be used as default for all Terminal shell.

## Setup WSL

If you intent to use [Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/) aka WSL.

```powershell
wsl --unregister ${existing-distro}
wsl --install -d Ubuntu-24.04
wsl --setdefault Ubuntu-24.04
```

## Setup Ubuntu-24.04

There are not much that needs to be done by default.  Start by updating the default installation.

```bash
sudo apt-get update && sudo apt-get upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
```

Install a few common dependencies for the upcoming steps.  I won't go into details about these.

```bash
sudo apt install curl git wget -y
```

## Setup ZSH

The Z shell (Zsh) is a Unix shell that can be used as an interactive login shell and as a command interpreter for shell scripting. Zsh is an extended Bourne shell with many improvements and is POSIX compliant.

```bash
sudo apt install zsh -y
```

### Setup OMZ

Oh My Zsh is a delightful, open source, community-driven framework for managing your Zsh configuration. It comes bundled with thousands of helpful functions, helpers, plugins, themes, and a few things that make you shout...

```bash
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
```

At this point your `~/.zshrc` and terminal experience looks really boring let's improve it.

```bash
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh
```

### Setup P10K theme

Install [Powerlevel10k](https://github.com/romkatv/powerlevel10k) a Zsh theme

> [!NOTE]
> Powerlevel10k project is deemed feature complete, has no roadmap for new features and most bugs will go unfixed.
> If you are not comfortable, look at [Starship](https://starship.rs/) which is a blazing-fast alternative to p10k.

```bash
git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
```

Edit your `~/.zshrc` and replace with `ZSH_THEME="powerlevel10k/powerlevel10k"` and run `source ~/.zshrc`.  You will be `p10k configure` will run automatically, follow the wizard configuration steps as per your desired.

### Setup plugins

OMZ comes with many plugins improving `zsh` experience.  Let's install the following dependencies.

```bash
sudo apt install bat eza git zoxide -y
```

**zsh-autosuggestions** => suggests commands as you type based on history and completions

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

**zsh-completions** => additional completion definitions

```bash
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
```

**zsh-syntax-highlightings** => syntax highlighting

```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

**you-should-use** => reminds you to use existing aliases for commands you just typed

```bash
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use
```

**zsh-bat** => for easy integration with `bat`

```bash
git clone https://github.com/fdellwing/zsh-bat.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-bat
```

**zsh-eza** => replace command `ls` with `e(x|z)a`

```bash
git clone https://github.com/renovate-bot/z-shell-_-zsh-eza ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-eza
```

**zsh-z** => for easy integration with `zoxide`

```bash
git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z
```

Edit your `~/.zshrc` and add the following `plugins` section and run `source ~/.zshrc`.

```bash
plugins=(
  command-not-found
  git
  history
  sudo
  vscode
  you-should-use
  z
  zsh-autosuggestions
  zsh-bat
  zsh-completions
  zsh-eza
  zsh-syntax-highlighting
  )
```

### Setup aliases and env

`.zshaliases` Command line aliases are very useful, allowing you to have command shortcuts for lengthier commands.

```bash
cd ~
curl https://raw.githubusercontent.com/irish1986/dotfiles/main/roles/zsh/files/.zshaliases -O
source ~/.zshrc
cat ~/.zshaliases
```

`.zshenv` is where you set environment variables, careful about commiting secrets to `git`.

```bash
cd ~
curl https://raw.githubusercontent.com/irish1986/dotfiles/main/roles/zsh/files/.zshenv -O
source ~/.zshrc
cat ~/.zshenv
```

## Setup TMUX

tmux is a terminal multiplexer. It lets you switch easily between several programs in one terminal, detach them (they keep running in the background) and reattach them to a different terminal

```bash
sudo apt install tmux -y
```

### Setup TPM

Tmux Plugin Manager (TPM) is a TMUX plugin manager, just like OMZ but for TMUX.

```bash
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
```

TMUX configuration can be rather complexe to explain, just get this files you should be good to go.

```bash
cd ~/.config/tmux/
curl https://raw.githubusercontent.com/irish1986/dotfiles/main/roles/tmux/files/tmux.conf -O
cat ~/.config/tmux/tmux.conf
```

TMUX can be integrated into ZSH to make everything more coherent.  Edit your `~/.zshrc`, add the following and run `source ~/.zshrc`.

```bash
ZSH_TMUX_AUTOSTART=true

plugins=(
  ...
  tmux
  ...
  )
```

TMUX will be launch automatically upon opening a terminal session.  For the first setup you need to enter the following keystroke:

`ctrl+spacebar` followd by `shift+i` which will trigger Tmux Plugin Manager and install dependencies.
You can manually run `tmux source ~/.config/tmux/tmux.conf` to reload tmux configuration

## Setup ansible

If you plan to run this automated playbook and edit `all.yml` configuration files.

```bash
sudo apt install ansible -y
cp ~/.dotfiles/inventory/group_vars/sample.yml ~/.dotfiles/inventory/group_vars/all.yml
```

## PIPX

I like to install the following tool for my workflow.

```bash
sudo apt install pipx -y
pipx install ggshield pre-commit
export PATH="/home/irish/.local/bin:$PATH"
```
