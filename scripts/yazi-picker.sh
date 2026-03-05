#!/bin/bash

# Yazi file picker wrapper for xdg-desktop-portal-termfilechooser
# Arguments:
# $1 = multiple (1=yes, 0=no)
# $2 = directory (1=yes, 0=no)
# $3 = save (0=open, 1=save)
# $4 = path (suggested save path)
# $5 = output file (write selected paths here)

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"

if [ "$save" = "1" ]; then
    # Save mode - start in the directory of the suggested path
    start_dir="$(dirname "$path")"
    alacritty --class floating-term -e yazi --chooser-file="$out" "$start_dir"
elif [ "$directory" = "1" ]; then
    # Directory selection mode
    alacritty --class floating-term -e yazi --chooser-file="$out" "$HOME"
else
    # Open file mode
    alacritty --class floating-term -e yazi --chooser-file="$out" "$HOME"
fi
