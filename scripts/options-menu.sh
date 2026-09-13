#!/bin/bash

# Options menu - shows available commands
# Used with sway's options mode

show_menu() {
    echo -en "Bluetooth (b)\0icon\x1fbluetooth\n"
    echo -en "Network (n)\0icon\x1fnetwork-wireless\n"
    echo -en "Audio (a)\0icon\x1faudio-volume-high\n"
    echo -en "Audio output (o)\0icon\x1faudio-speakers\n"
    echo -en "Displays (d)\0icon\x1fpreferences-desktop-display\n"
    echo -en "Screenshot (s)\0icon\x1fapplets-screenshooter\n"
    echo -en "Record (r)\0icon\x1fmedia-record\n"
    echo -en "Clipboard (c)\0icon\x1fedit-paste\n"
    echo -en "Color picker (k)\0icon\x1fapplications-graphics\n"
    echo -en "System monitor (t)\0icon\x1futilities-system-monitor\n"
    echo -en "Files (f)\0icon\x1fsystem-file-manager\n"
    echo -en "Emoji (e)\0icon\x1fface-smile\n"
    echo -en "Lock (l)\0icon\x1fsystem-lock-screen\n"
    echo -en "Power menu (p)\0icon\x1fsystem-shutdown\n"
    echo -en "Cancel (q)\0icon\x1fwindow-close\n"
}

chosen=$(show_menu | rofi -dmenu -p "Options" -show-icons)

case "$chosen" in
    *"(b)"*) alacritty --class floating-term -e bluetuith ;;
    *"(n)"*) alacritty --class floating-term -e ~/dotfiles/scripts/nmtui-kanagawa.sh ;;
    *"(a)"*) alacritty --class floating-term -e pulsemixer ;;
    *"(o)"*) ~/dotfiles/scripts/audio-output-menu.sh ;;
    *"(d)"*) wdisplays ;;
    *"(s)"*) ~/dotfiles/scripts/screenshot-menu.sh ;;
    *"(r)"*) ~/dotfiles/scripts/recorder-menu.sh ;;
    *"(c)"*) ~/dotfiles/scripts/clipboard-history.sh ;;
    *"(k)"*) hyprpicker -a ;;
    *"(t)"*) alacritty --class floating-term -e btop ;;
    *"(f)"*) alacritty --class floating-term -e yazi ;;
    *"(e)"*) rofimoji --action copy ;;
    *"(l)"*) swaylock -f ;;
    *"(p)"*) ~/dotfiles/scripts/power-menu.sh ;;
    *) exit 0 ;;
esac
