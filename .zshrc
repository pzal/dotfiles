NEWLINE=$'\n'
RPROMPT="%F{024}%*%f"
PROMPT="${NEWLINE}%F{028}%B%n%b%f@%F{024}%B%m%b%f %F{240}%~%f %(?..%F{160}exit %?%f)${NEWLINE}%F{024}%B>%b%f "

export EDITOR="nvim"
export VISUAL="$EDITOR"
export GIT_EDITOR="$EDITOR"

export PATH="${HOME}/.local/bin:${PATH}"

alias ls='ls --color'


# git
alias gits='git status'
alias gitp='git pull'
alias gitc='git checkout'
alias gitl='git log'


set -o emacs


# fzf for command history
if command -v fzf >/dev/null 2>&1; then
	source <(fzf --zsh)
fi


# Zsh completion which is case-insensitive
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'


# History
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=$HISTSIZE


export LANG=C.UTF-8
