#!/bin/bash

set -eu

if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/you-should-use" ]; then
  git clone https://github.com/MichaelAquilina/zsh-you-should-use ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use
  echo "you-should-use plugin installed."
fi

if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-exa" ]; then
  git clone https://github.com/ptavares/zsh-exa ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-exa
  echo "zsh-exa plugin installed."
fi

if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  echo "zsh-autosuggestions plugin installed."
fi

if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  echo "zsh-syntax-highlighting plugin installed."
fi
