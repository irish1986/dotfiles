# A person at a terminal, as opposed to an agent or tool that sources this file (Claude Code runs its commands in a shell built from it; CLAUDECODE is set in all of its subprocesses). Gates the aliases and hooks that change what ordinary commands do -- cat, ls, rm, cd -- which break or hang non-interactive callers. Tested before the instant prompt, which redirects stdout while the rest of this file runs.
[[ -o interactive && -t 0 && -t 1 && -z $CLAUDECODE ]] && _dotfiles_terminal=1 || _dotfiles_terminal=

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

plugins=(
  command-not-found
  git
  history
  sudo
  vscode
  you-should-use
  zsh-autosuggestions
  zsh-syntax-highlighting
  )
# zsh-bat aliases cat to bat, and zsh-eza aliases ls to eza -- and calls `exit 1` when eza is missing, closing the shell.
if [[ -n $_dotfiles_terminal ]]; then
  (( $+commands[batcat] || $+commands[bat] )) && plugins+=(zsh-bat)
  (( $+commands[eza] )) && plugins+=(zsh-eza)
fi

ZSH_THEME="powerlevel10k/powerlevel10k"

export CONFIG="$HOME/.config"
export ZSH="$HOME/.oh-my-zsh"

# On fpath before oh-my-zsh runs compinit, rather than listed in plugins=(): as a plugin it lands on fpath after compinit, so its completions only registered because of a second compinit at the end of this file, which cost a full rescan on every start. The zsh-completions README gives the same advice.
fpath+=($ZSH/custom/plugins/zsh-completions/src)

source $ZSH/oh-my-zsh.sh

# Guarded: on a fresh box, or any shell opened before the playbook finishes, an unguarded source prints an error on every prompt. ~/.zshenv is not sourced here -- zsh reads it automatically, and first, so doing it again double-loads.
[[ -r $HOME/.local/bin/env ]] && source $HOME/.local/bin/env
[[ -r $HOME/.cargo/env ]] && source $HOME/.cargo/env

# The tools role installs nvm with PROFILE=/dev/null, so its installer never edits this file; loading it is this block's job. Loaded on first use: sourcing nvm.sh cost ~300 ms per shell. The newest installed node goes on PATH directly so its global npm binaries work without loading nvm; `nvm use` in a shell still overrides it.
export NVM_DIR="$HOME/.nvm"
if [[ -r $NVM_DIR/nvm.sh ]]; then
  _dotfiles_node=($NVM_DIR/versions/node/v*/bin(N/nOn[1]))
  (( $#_dotfiles_node )) && path=($_dotfiles_node $path)
  unset _dotfiles_node
  nvm() { unfunction nvm; source $NVM_DIR/nvm.sh; nvm "$@" }
fi

# Completion and init scripts, generated once per binary version rather than on every start: each `eval "$(tool ...)"` forked the tool, ~50 ms apiece.
_dotfiles_cached() {
  local name=$1 bin=${commands[$2]}
  shift
  local file=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/$name.zsh
  if [[ ! -s $file || $bin -nt $file ]]; then
    mkdir -p ${file:h} && "$@" >| $file 2>/dev/null || return 0
  fi
  source $file
}
(( $+commands[uv] )) && _dotfiles_cached uv uv generate-shell-completion zsh
(( $+commands[uvx] )) && _dotfiles_cached uvx uvx --generate-shell-completion zsh
(( $+commands[zoxide] )) && _dotfiles_cached zoxide zoxide init zsh
(( $+commands[herdr] )) && _dotfiles_cached herdr herdr completion zsh
unfunction _dotfiles_cached

# After the generated scripts, so none of them captures an alias defined here.
[[ -r $HOME/.zshaliases ]] && source $HOME/.zshaliases
[[ -r $HOME/.zshfunc ]] && source $HOME/.zshfunc

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -U +X bashcompinit && bashcompinit

unset _dotfiles_terminal
