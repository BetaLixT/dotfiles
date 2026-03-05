#!/bin/bash

# Screenshot menu

OPTIONS="󰹑  Area (select)
  Fullscreen
  Window
󰔝  Area (select, 5s delay)
  Fullscreen (5s delay)"

chosen=$(echo -e "$OPTIONS" | rofi -dmenu -p "Screenshot")

case "$chosen" in
    *"Area (select)"*) grim -g "$(slurp)" - | wl-copy -t image/png && notify-send "Screenshot" "Area copied to clipboard" ;;
    *"Fullscreen"*) grim - | wl-copy -t image/png && notify-send "Screenshot" "Fullscreen copied to clipboard" ;;
    *"Window"*) grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" - | wl-copy -t image/png && notify-send "Screenshot" "Window copied to clipboard" ;;
    *"Area (select, 5s delay)"*) area=$(slurp) && notify-send "Screenshot" "Capturing in 5 seconds..." && sleep 5 && grim -g "$area" - | wl-copy -t image/png && notify-send "Screenshot" "Area copied to clipboard" ;;
    *"Fullscreen (5s delay)"*) notify-send "Screenshot" "5 seconds..." && sleep 5 && grim - | wl-copy -t image/png && notify-send "Screenshot" "Fullscreen copied to clipboard" ;;
    *) exit 0 ;;
esac
