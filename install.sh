#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

# Install dependencies
sudo apt update
sudo apt install -y zsh tmux neovim git curl xclip

# Install oh-my-zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Symlink configs
mkdir -p "$HOME/.config"

# nvim
if [ -e "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    echo "~/.config/nvim exists and is not a symlink, backing up to ~/.config/nvim.bak"
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
fi
ln -sfn "$DIR/nvim" "$HOME/.config/nvim"

# zshrc
if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    echo "~/.zshrc exists and is not a symlink, backing up to ~/.zshrc.bak"
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
ln -sf "$DIR/.zshrc" "$HOME/.zshrc"

# tmux
if [ -e "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
    echo "~/.tmux.conf exists and is not a symlink, backing up to ~/.tmux.conf.bak"
    mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
fi
ln -sf "$DIR/.tmux.conf" "$HOME/.tmux.conf"

# Set zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
fi

echo "Done! Log out and back in for zsh to take effect."
