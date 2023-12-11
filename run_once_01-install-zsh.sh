#!/bin/bash

set -eu

if ! command -v zsh >/dev/null; then
  sudo apt update && sudo apt install zsh -y
  echo "ZSH package installed."
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc --skip-chsh
  echo "oh-my-zsh package installed."
fi

if ! command -v git >/dev/null; then
  sudo apt update
  sudo apt install git -y
  echo "Git package was installed, required for the next step."
fi

if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  echo "powerlevelk10k theme installed."
fi
