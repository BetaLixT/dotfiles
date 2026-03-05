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

# swaylock
mkdir -p $HOME/.config/swaylock
ln -sf $DIR/swaylock/config $HOME/.config/swaylock/config

# rofi
remove_non_dirlink $HOME/.config/rofi
ln -sfn $DIR/rofi $HOME/.config/rofi

# systemd
remove_non_dirlink $HOME/.config/systemd
ln -sfn $DIR/systemd-sway-arch $HOME/.config/systemd

# networkmanager-dmenu
remove_non_dirlink $HOME/.config/networkmanager-dmenu
ln -sfn $DIR/networkmanager-dmenu $HOME/.config/networkmanager-dmenu

# bluetuith
remove_non_dirlink $HOME/.config/bluetuith
ln -sfn $DIR/bluetuith $HOME/.config/bluetuith

# btop theme
mkdir -p $HOME/.config/btop/themes
cp $DIR/btop/themes/kanagawa.theme $HOME/.config/btop/themes/

# swayosd
mkdir -p $HOME/.config/swayosd
ln -sf $DIR/swayosd/style.css $HOME/.config/swayosd/style.css

# yazi
mkdir -p $HOME/.config/yazi/flavors
ln -sf $DIR/yazi/theme.toml $HOME/.config/yazi/theme.toml
git clone https://github.com/dangooddd/kanagawa.yazi.git $HOME/.config/yazi/flavors/kanagawa.yazi 2>/dev/null || true

# Default applications
ln -sf $DIR/mimeapps/mimeapps.list $HOME/.config/mimeapps.list

# GTK theme
mkdir -p $HOME/.config/gtk-3.0 $HOME/.config/gtk-4.0
ln -sf $DIR/gtk-3.0/settings.ini $HOME/.config/gtk-3.0/settings.ini
ln -sf $DIR/gtk-4.0/settings.ini $HOME/.config/gtk-4.0/settings.ini

# xdg-desktop-portal (yazi as file picker)
mkdir -p $HOME/.config/xdg-desktop-portal-termfilechooser
mkdir -p $HOME/.config/xdg-desktop-portal
ln -sf $DIR/xdg-desktop-portal-termfilechooser/config $HOME/.config/xdg-desktop-portal-termfilechooser/config
ln -sf $DIR/xdg-desktop-portal/portals.conf $HOME/.config/xdg-desktop-portal/portals.conf

systemctl --user daemon-reload
systemctl --user enable --now battery-monitor.timer
