#!/bin/bash

# Power menu

OPTIONS="⏻  Shutdown
  Reboot
⏾  Suspend
  Lock
  Logout"

chosen=$(echo -e "$OPTIONS" | rofi -dmenu -p "Power")

case "$chosen" in
    *Shutdown) systemctl poweroff ;;
    *Reboot) systemctl reboot ;;
    *Suspend) systemctl suspend ;;
    *Lock) swaylock -f ;;
    *Logout) swaymsg exit ;;
    *) exit 0 ;;
esac
