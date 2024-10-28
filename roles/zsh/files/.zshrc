if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export CONFIG="$HOME/.config"
# export MANPATH="/usr/local/man:$MANPATH"
# export PATH=$HOME/bin:/usr/local/bin:$PATH:$HOME/.local/bin
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_TMUX_AUTOSTART=true

# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' frequency 7    # update automatically after x days
# zstyle ':completion:*:git-checkout:*' sort false # disable sort when completing `git checkout`
# zstyle ':completion:*:descriptions' format '[%d]' # set descriptions format to enable group support
# zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # set list-colors to enable filename colorizing
# zstyle ':completion:*' menu no # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix

plugins=(
  command-not-found
  fzf
  git
  history
  sudo
  tmux
  vscode
  you-should-use
  z
  zsh-autosuggestions
  zsh-bat
  zsh-completions
  zsh-eza
  zsh-syntax-highlighting
  )

source $ZSH/oh-my-zsh.sh
source $CONFIG/zsh/.zsh_aliases

eval "$(register-python-argcomplete pipx)"
eval "$(register-python-argcomplete cz)"
eval "$(zoxide init zsh)"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh # run `p10k configure`

autoload -U compinit
autoload -U bashcompinit
compinit -i
bashcompinit
