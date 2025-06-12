if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

plugins=(
  command-not-found
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

ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_TMUX_AUTOSTART=true

export CONFIG="$HOME/.config"
export ZSH="$HOME/.oh-my-zsh"

source $ZSH/oh-my-zsh.sh
source $HOME/.local/bin/env
source $HOME/.zshaliases
source $HOME/.zshenv

eval "$(register-python-argcomplete cz)"
eval "$(register-python-argcomplete pipx)"
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"
eval "$(zoxide init zsh)"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -U +X bashcompinit && bashcompinit
autoload -Uz compinit && compinit
