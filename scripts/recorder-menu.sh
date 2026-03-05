#!/bin/bash

# Screen recorder menu

# Check if already recording
if pgrep -x wf-recorder > /dev/null; then
    pkill -INT wf-recorder
    notify-send "Recording" "Saved to ~/Videos"
    exit 0
fi

OPTIONS="  Fullscreen
  Fullscreen + Audio
󰒅  Area
󰒅  Area + Audio
  Stop recording"

chosen=$(echo -e "$OPTIONS" | rofi -dmenu -p "Record")

FILENAME=~/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4

case "$chosen" in
    *"Fullscreen + Audio"*) wf-recorder -f "$FILENAME" -a & notify-send "Recording" "Fullscreen + Audio" ;;
    *"Fullscreen"*) wf-recorder -f "$FILENAME" & notify-send "Recording" "Fullscreen" ;;
    *"Area + Audio"*) wf-recorder -g "$(slurp)" -f "$FILENAME" -a & notify-send "Recording" "Area + Audio" ;;
    *"Area"*) wf-recorder -g "$(slurp)" -f "$FILENAME" & notify-send "Recording" "Area" ;;
    *"Stop"*) pkill -INT wf-recorder && notify-send "Recording" "Saved to ~/Videos" ;;
    *) exit 0 ;;
esac
