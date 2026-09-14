#!/bin/bash

# Link dest -> src, replacing whatever is at dest.
#
# Prompts ONLY when real content would be lost. Stays silent when:
#   * dest is already a symlink to src           -> nothing to do
#   * dest is a symlink pointing elsewhere       -> repoint it
#   * dest is a dir whose every entry is a
#     symlink resolving inside src               -> equivalent, replace
#   * dest is an empty dir                       -> nothing to lose
# Anything else (real files, or symlinks out of src) is content worth keeping,
# so it asks. Declining leaves dest untouched.
#
# Uses `find` rather than a glob to enumerate entries: it handles empty dirs and
# dotfiles without needing `shopt -s nullglob` (bash-only) or `(N)` (zsh-only).
link_path() {
    local src=$1 dest=$2 real_src safe e
    real_src=$(readlink -f "$src")

    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$real_src" ]; then
        return 0
    fi

    if [ -L "$dest" ]; then
        rm -f "$dest"
    elif [ -d "$dest" ]; then
        safe=1
        while IFS= read -r e; do
            [ -n "$e" ] || continue
            if [ ! -L "$e" ]; then safe=0; break; fi
            case "$(readlink -f "$e")" in
                "$real_src"/*) ;;
                *) safe=0; break ;;
            esac
        done <<EOT
$(find "$dest" -mindepth 1 -maxdepth 1 2>/dev/null)
EOT
        if [ "$safe" = 1 ]; then
            rm -rf "$dest"
        else
            echo "${dest} has real content; overwrite it with a symlink to ${src}?"
            rm -rI "$dest"
            [ -e "$dest" ] && return 0
        fi
    elif [ -e "$dest" ]; then
        echo "${dest} exists as a real file; overwrite with a symlink to ${src}?"
        rm -i "$dest"
        [ -e "$dest" ] && return 0
    fi

    ln -sfn "$src" "$dest"
}

DIR="$(dirname "$(readlink -f "$0")")"
cd $DIR


mkdir -p $HOME/.config

# nvim
link_path $DIR/nvim $HOME/.config/nvim

# zed
link_path $DIR/zed $HOME/.config/zed

# wallpapers
link_path $DIR/wallpapers $HOME/.config/wallpapers

# ZSH config
# oh-my-zsh is a dependency, not repo content: it is its own 16MB upstream clone.
# .zshrc-lnx sources it, so clone it here too rather than relying on bootstrap.sh
# having been run first -- this script has to stand on its own.
if [ ! -d $HOME/.oh-my-zsh ]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git $HOME/.oh-my-zsh \
        || echo "WARNING: oh-my-zsh clone failed; zsh will start without theme/plugins" >&2
fi
link_path $DIR/.zshrc-lnx $HOME/.zshrc

# tmux config
link_path $DIR/.tmux.conf $HOME/.tmux.conf

# alacritty
link_path $DIR/alacritty-lnx $HOME/.config/alacritty

# sway
link_path $DIR/sway $HOME/.config/sway

# swaync (notification daemon; replaced mako — needs: sudo pacman -S swaync)
link_path $DIR/swaync $HOME/.config/swaync

# mako (kept as fallback notification daemon config)
link_path $DIR/mako $HOME/.config/mako

# swaylock
mkdir -p $HOME/.config/swaylock
ln -sf $DIR/swaylock/config $HOME/.config/swaylock/config

# rofi
link_path $DIR/rofi $HOME/.config/rofi

# systemd
link_path $DIR/systemd-sway-arch $HOME/.config/systemd

# networkmanager-dmenu
link_path $DIR/networkmanager-dmenu $HOME/.config/networkmanager-dmenu

# bluetuith
link_path $DIR/bluetuith $HOME/.config/bluetuith

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

# Zen browser (user.js for GPU stability)
ZEN_PROFILE=$(find $HOME/.zen -maxdepth 1 -type d -name "*.Default*" | head -1)
if [ -n "$ZEN_PROFILE" ]; then
    ln -sf $DIR/zen/user.js "$ZEN_PROFILE/user.js"
fi

# Session-wide environment. These used to be exported from .zshrc-lnx, which
# only worked while sway was launched from an interactive zsh. greetd execs the
# session directly and never sources ~/.zshrc, so they moved here.
# NOTE: environment.d alone only reaches systemd user services; sway is spawned
# by greetd into session-N.scope, so scripts/start-sway.sh sources this dir
# explicitly. Both halves are required.
link_path $DIR/environment.d $HOME/.config/environment.d

# sway launcher that captures sway's log into the journal (journalctl -t sway).
# sway has no config directive for logging, so this has to be done at launch.
# Run `start-sway` instead of `sway`.
mkdir -p $HOME/.local/bin
ln -sf $DIR/scripts/start-sway.sh $HOME/.local/bin/start-sway
# Also install it system-wide. greetd launches sessions with a minimal
# environment that does NOT include ~/.local/bin, so a session entry pointing at
# the home copy can never resolve. /usr/local/bin is on the default PATH.
sudo install -Dm755 $DIR/scripts/start-sway.sh /usr/local/bin/start-sway

# herdr (terminal multiplexer for coding agents; AUR: yay -S herdr-bin)
# NOTE: link the file, not the directory -- ~/.config/herdr also holds herdr.sock,
# session.json and logs, which must stay local and out of the repo.
mkdir -p $HOME/.config/herdr
ln -sf $DIR/herdr/config.toml $HOME/.config/herdr/config.toml

# System configs (require sudo)
sudo cp $DIR/system/sysctl.d/99-sysrq.conf /etc/sysctl.d/99-sysrq.conf
sudo cp $DIR/system/sysctl.d/99-memory-pressure.conf /etc/sysctl.d/99-memory-pressure.conf
sudo sysctl --system > /dev/null 2>&1

sudo mkdir -p /etc/systemd/journald.conf.d
sudo cp $DIR/system/journald.conf.d/00-persistent.conf /etc/systemd/journald.conf.d/00-persistent.conf
sudo systemctl restart systemd-journald

# zram - tier-1 compressed-RAM swap at priority 100. Must exist before the
# swapfile below is meaningful; the two-tier design depends on it.
pacman -Qq zram-generator > /dev/null 2>&1 || sudo pacman -S --needed --noconfirm zram-generator
sudo cp $DIR/system/systemd/zram-generator.conf /etc/systemd/zram-generator.conf

# earlyoom - userspace OOM killer, kills a runaway before the desktop stalls
pacman -Qq earlyoom > /dev/null 2>&1 || sudo pacman -S --needed --noconfirm earlyoom
sudo cp $DIR/system/default/earlyoom /etc/default/earlyoom

# Disk swapfile behind zram (btrfs-aware; idempotent, safe to re-run)
sudo $DIR/system/setup-swapfile.sh

# Fonts
#
# `SFMono Nerd Font` is the family named by BOTH alacritty configs: the desktop
# terminal (alacritty-lnx/alacritty.toml) and the greeter (system/greetd/
# alacritty.toml). The faces are vendored in fonts/ -- see the README there.
#
# Installed system-wide, NOT into ~/.local/share/fonts, because greetd runs the
# greeter as the `greeter` user, which cannot read /home/dcruza (mode 0750; its
# ACL grants only rslsync). With a user-local install the login screen silently
# fell back to Nimbus Mono PS -- fontconfig reports no error for a missing
# family, it just substitutes.
#
# /usr/local/share/fonts is the correct location for fonts not managed by
# pacman, and the stock fontconfig already scans it. Filenames contain spaces,
# hence find -exec ... {} + rather than a glob.
sudo install -d -m 0755 /usr/local/share/fonts/SF-Mono-Nerd-Font
sudo find "$DIR/fonts/SF-Mono-Nerd-Font" -maxdepth 1 -name '*.otf' \
    -exec install -m 0644 -t /usr/local/share/fonts/SF-Mono-Nerd-Font {} +
sudo fc-cache -f /usr/local/share/fonts > /dev/null

# Guard the silent-fallback case above: resolve the family the way the greeter
# sees it, with no home directory in the picture.
if ! env -i HOME=/nonexistent fc-match "SFMono Nerd Font" 2>/dev/null \
        | grep -qi sfmono; then
    echo "WARNING: 'SFMono Nerd Font' does not resolve system-wide;" \
         "the login screen will fall back to another font." >&2
fi

# Login screen: greetd + cage + alacritty + tuigreet
#
# Why the wrapper: tuigreet is a TUI, and a bare Linux VT is an 8-colour
# terminal (`tput -T linux colors` -> 8), which crushes Kanagawa hex values to
# grey. Running it inside alacritty inside cage gives truecolor and real font
# rendering. This replaced ly, which has vi keybindings but is stuck on the VT.
#
# ly is deliberately left installed and its config still deployed, so
# `systemctl enable ly@tty2` is a one-command fallback if greetd misbehaves.
pacman -Qq greetd > /dev/null 2>&1 || sudo pacman -S --needed --noconfirm greetd
pacman -Qq greetd-tuigreet > /dev/null 2>&1 || sudo pacman -S --needed --noconfirm greetd-tuigreet
pacman -Qq cage > /dev/null 2>&1 || sudo pacman -S --needed --noconfirm cage

sudo mkdir -p /etc/greetd /etc/tuigreet
# The greeter wrapper: prefers the locally built tuigreet (which adds the `wave`
# animation), falls back to the packaged binary when that build is absent.
# Installed BEFORE the greetd config below, which names it -- so the config can
# never point at something that does not exist yet.
sudo install -Dm755 $DIR/scripts/tuigreet-custom.sh /usr/local/bin/tuigreet-custom
sudo cp $DIR/system/greetd/config.toml /etc/greetd/config.toml
# Separate alacritty config: the greeter runs as the `greeter` user and cannot
# read /home/dcruza/.config/alacritty.
sudo cp $DIR/system/greetd/alacritty.toml /etc/greetd/alacritty.toml
sudo cp $DIR/system/tuigreet/config.toml /etc/tuigreet/config.toml
# Session entries. Two destinations, on purpose:
#   /etc/greetd/sessions      the ONLY dir tuigreet reads (see its config), so
#                             the single offered session always logs
#   /usr/share/wayland-sessions  standard location, used by the ly fallback
sudo install -Dm644 $DIR/system/greetd/sessions/sway-logged.desktop \
    /etc/greetd/sessions/sway-logged.desktop
sudo install -Dm644 $DIR/system/wayland-sessions/sway-logged.desktop \
    /usr/share/wayland-sessions/sway-logged.desktop

# Pre-seed tuigreet's remembered session so the first login after a fresh
# install already picks the logged entry rather than whatever was cached before.
if id greeter > /dev/null 2>&1; then
    sudo mkdir -p /var/cache/tuigreet
    echo /etc/greetd/sessions/sway-logged.desktop \
        | sudo tee /var/cache/tuigreet/lastsession-path-$USER > /dev/null
    sudo chown -R greeter:greeter /var/cache/tuigreet
    sudo chmod 0755 /var/cache/tuigreet
fi
# Cache dir is required for --remember* to persist between logins.
sudo mkdir -p /var/cache/tuigreet
sudo chown greeter:greeter /var/cache/tuigreet 2>/dev/null || true
sudo chmod 0755 /var/cache/tuigreet

# Custom tuigreet build: adds the `wave` background animation, which upstream
# cannot load at runtime (animations are Rust, registered at compile time).
#
# Entirely optional. build.sh is a no-op when its stamp is current, so re-running
# this script does not trigger a multi-minute Rust build. If anything fails --
# no toolchain, no network, patch no longer applies -- nothing is installed,
# tuigreet-custom falls back to the packaged greeter, and an unknown
# `kind = "wave"` degrades to no animation. A failure here cannot cost a login.
#
# Skip the toolchain entirely on a minimal machine:
#     SKIP_TUIGREET_BUILD=1 ./install-sway-arch.sh
#
# See docs/tuigreet-wave.md for the update workflow and the version pin.
if [ "${SKIP_TUIGREET_BUILD:-0}" != 1 ]; then
    pacman -Qq rust > /dev/null 2>&1 || sudo pacman -S --needed --noconfirm rust
    $DIR/system/tuigreet/build.sh || \
        echo "WARNING: custom tuigreet build failed; the greeter falls back to the packaged binary (no 'wave' animation). See docs/tuigreet-wave.md." >&2
fi

# ly config still deployed as the fallback path (package already installed)
if pacman -Qq ly > /dev/null 2>&1; then
    sudo cp $DIR/system/ly/config.ini /etc/ly/config.ini
    sudo mkdir -p /etc/ly/custom-sessions
    sudo cp $DIR/system/ly/custom-sessions/sway-logged.desktop /etc/ly/custom-sessions/
fi

# Only one display manager may own a VT. greetd wins; ly is disabled but kept.
sudo systemctl disable ly@tty2.service 2>/dev/null || true
sudo systemctl enable greetd.service

# Services
# sshd is the escape hatch for diagnosing a freeze from another machine, so the
# package guard matters here -- enabling a unit that isn't installed just fails.
pacman -Qq openssh > /dev/null 2>&1 || sudo pacman -S --needed --noconfirm openssh
sudo systemctl enable --now sshd
sudo systemctl enable --now earlyoom
sudo systemctl restart earlyoom   # pick up /etc/default/earlyoom if already running

systemctl --user daemon-reload
systemctl --user enable --now battery-monitor.timer
