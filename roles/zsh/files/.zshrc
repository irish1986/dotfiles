# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Where to look for autoloaded function definitions
fpath=(~/.config/zsh/zfunc $fpath)

for func in $^fpath/*(N-.x:t); autoload $func

# automatically remove duplicates from these arrays
typeset -U path cdpath fpath manpath

# General configuration
export PATH=$HOME/bin:/usr/local/bin:$PATH:$HOME/.local/bin
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  docker
  git
  kubectl
  sudo
  you-should-use
  z
  zsh-autosuggestions
  zsh-bat
  zsh-syntax-highlighting
)

autoload -U compinit
compinit -i

# User configuration

# P10K configuration
# Run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source $ZSH/oh-my-zsh.sh
