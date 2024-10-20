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

# i3
remove_non_dirlink $HOME/.config/i3
ln -sfn $DIR/i3kde $HOME/.config/i3

# i3blocks
# remove_non_dirlink $HOME/.config/i3blocks
# ln -sfn $DIR/i3blocks $HOME/.config

# regolith folder
# mkdir -p $HOME/.config/regolith2

# i3 regolith user
# remove_non_dirlink $HOME/.config/regolith
# ln -sfn $DIR/regolith $HOME/.config

# i3 regolith2 user
# remove_non_dirlink $HOME/.config/regolith2
# ln -sfn $DIR/regolith2 $HOME/.config

# wallpapers
remove_non_dirlink $HOME/.config/wallpapers
ln -sfn $DIR/wallpapers $HOME/.config

# Kitty config
# remove_non_dirlink $HOME/.config/kitty
# ln -sfn $DIR/kitty $HOME/.config

# ZSH config
remove_non_dirlink $HOME/.zshrc
ln -s $DIR/.zshrc-lnx $HOME/.zshrc

# tmux config
remove_non_dirlink $HOME/.tmux.conf
ln -s $DIR/.tmux.conf $HOME/.tmux.conf

# Xresources
# remove_non_dirlink $HOME/.Xresources
# ln -s $DIR/.Xresources $HOME/.Xresources
#
## systemd
remove_non_dirlink $HOME/.config/systemd
ln -sfn $DIR/systemd $HOME/.config

# alacritty
remove_non_dirlink $HOME/.config/alacritty
ln -sfn $DIR/alacritty-lnx $HOME/.config/alacritty

# rofi
remove_non_dirlink $HOME/.config/rofi
ln -sfn $DIR/rofi $HOME/.config


# Xdefaults
remove_non_dirlink $HOME/.Xdefaults
ln -s $DIR/.Xdefaults $HOME/.Xdefaults

# dunst
remove_non_dirlink $HOME/.config/dunst
ln -sfn $DIR/dunst $HOME/.config

# scripts
remove_non_dirlink $HOME/.config/scripts
ln -sfn $DIR/scripts $HOME/.config

# hypr
remove_non_dirlink $HOME/.config/hypr
ln -sfn $DIR/hypr $HOME/.config
