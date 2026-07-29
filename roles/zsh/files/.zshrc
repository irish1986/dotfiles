if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

plugins=(
  command-not-found
  git
  kubectl
  history
  sudo
  vscode
  you-should-use
  zsh-autosuggestions
  zsh-bat
  zsh-completions
  zsh-eza
  zsh-syntax-highlighting
  )

ZSH_THEME="powerlevel10k/powerlevel10k"

export CONFIG="$HOME/.config"
export ZSH="$HOME/.oh-my-zsh"

source $ZSH/oh-my-zsh.sh

# Guarded: on a fresh box, or any shell opened before the playbook finishes,
# an unguarded source prints an error on every prompt. ~/.zshenv is not sourced
# here -- zsh reads it automatically, and first, so doing it again double-loads.
[[ -r $HOME/.local/bin/env ]] && source $HOME/.local/bin/env
[[ -r $HOME/.zshaliases ]] && source $HOME/.zshaliases
[[ -r $HOME/.zshfunc ]] && source $HOME/.zshfunc

# Completion registration, each behind its own guard for the same reason.
(( $+commands[register-python-argcomplete] )) && {
  eval "$(register-python-argcomplete cz 2>/dev/null)"
}
(( $+commands[uv] )) && eval "$(uv generate-shell-completion zsh)"
(( $+commands[uvx] )) && eval "$(uvx --generate-shell-completion zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -U +X bashcompinit && bashcompinit
autoload -Uz compinit && compinit
