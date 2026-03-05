export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="alanpeabody"

plugins=(git z)

source $ZSH/oh-my-zsh.sh

zstyle ':completion:*' completer _complete _ignored
zstyle :compinstall filename "$HOME/.zshrc"

autoload -Uz compinit
compinit

HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=100000
unsetopt beep

alias v="nvim"
alias vi="nvim"
alias vim="nvim"
alias lg="lazygit"

export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/bin:$PATH
export PATH=$HOME/go/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH
export PATH=/usr/local/go/bin:$PATH
export EDITOR=nvim
