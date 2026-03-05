#!/bin/bash
theme_overrides="listview { enabled: false;} num-rows { enabled: false;} num-filtered-rows { enabled: false;} case-indicator { enabled: false;} textbox-num-sep { enabled: false;}"

workspace=$(rofi -dmenu -p "New workspace" -theme-str "$theme_overrides")
[[ -z $workspace ]] && exit
swaymsg workspace $workspace
IFS=':' read -ra cdpaths <<< "$CDPATH"
for path in "${cdpaths[@]}"; do
    echo "$path/$workspace"
done
