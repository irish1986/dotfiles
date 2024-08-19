if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH=$HOME/bin:/usr/local/bin:$PATH:$HOME/.local/bin

export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh
source $HOME/.zsh_aliases
source $HOME/.zsh_func

ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#663399,standout"

# Uncomment one of the following lines to change the auto-update behavior
zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' frequency 7

plugins=(
  command-not-found
  git
  fzf
  history
  sudo
  you-should-use
  z
  zsh-autosuggestions
  zsh-bat
  zsh-eza
  zsh-syntax-highlighting
)

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -U compinit
compinit -i

eval "$(zoxide init zsh)"
