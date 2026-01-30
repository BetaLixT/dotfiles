#!/bin/bash

remove_non_dirlink() {
    if [[ -e $1 && ! -L $1 ]]; then
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

# zed
remove_non_dirlink $HOME/.config/zed
ln -sfn $DIR/zed $HOME/.config

# wallpapers
remove_non_dirlink $HOME/.config/wallpapers
ln -sfn $DIR/wallpapers $HOME/.config

# ZSH config
remove_non_dirlink $HOME/.zshrc
ln -s $DIR/.zshrc-lnx $HOME/.zshrc

# tmux config
remove_non_dirlink $HOME/.tmux.conf
ln -s $DIR/.tmux.conf $HOME/.tmux.conf

# alacritty
remove_non_dirlink $HOME/.config/alacritty
ln -sfn $DIR/alacritty-lnx $HOME/.config/alacritty

# sway
remove_non_dirlink $HOME/.config/sway
ln -sfn $DIR/sway $HOME/.config/sway

# mako
remove_non_dirlink $HOME/.config/mako
ln -sfn $DIR/mako $HOME/.config/mako

# systemd
remove_non_dirlink $HOME/.config/systemd
ln -sfn $DIR/systemd-sway-arch $HOME/.config/systemd

systemctl --user daemon-reload
systemctl --user enable --now battery-monitor.timer
