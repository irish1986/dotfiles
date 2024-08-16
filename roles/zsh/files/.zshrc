# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# automatically remove duplicates from these arrays
typeset -U path cdpath fpath manpath

# General configuration
export PATH=$HOME/bin:/usr/local/bin:$PATH:$HOME/.local/bin
export ZSH="$HOME/.oh-my-zsh"

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T" # add timestamp to history
export HISTCONTROL=erasedups:ignoredups:ignor

# Set the default editor
# export EDITOR=nvim
# export VISUAL=nvim

source $ZSH/oh-my-zsh.sh
source $HOME/.zsh_aliases

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  command-not-found
  git
  history
  sudo
  you-should-use
  z
  zsh-autosuggestions
  zsh-bat
  zsh-eza
  zsh-syntax-highlighting
)

# P10K configuration - Run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -U compinit
compinit -i
