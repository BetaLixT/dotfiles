#!/bin/bash

remove_non_dirlink() {
    if [[ ! (-L $1 && -d $1) && -d $1 || -f $1 ]]; then
        echo "${1} exists, do you want to overwrite it with a symlink?"
        rm -rI $1
    fi
}

DIR="$(dirname "$(readlink -f "$0")")"
cd $DIR


mkdir -p $HOME/.config

# nvim
remove_non_dirlink $HOME/.config/nvim
ln -sfn $DIR/nvim $HOME/.config

# wallpapers
remove_non_dirlink $HOME/.config/wallpapers
ln -sfn $DIR/wallpapers $HOME/.config

# ZSH config
remove_non_dirlink $HOME/.zshrc
ln -s $DIR/.zshrc $HOME/.zshrc

# tmux config
remove_non_dirlink $HOME/.tmux.conf
ln -s $DIR/.tmux.conf $HOME/.tmux.conf

# alacritty
remove_non_dirlink $HOME/.config/alacritty
ln -sfn $DIR/alacritty $HOME/.config

