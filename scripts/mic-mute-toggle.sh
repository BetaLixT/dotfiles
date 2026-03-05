#!/bin/bash
pactl set-source-mute @DEFAULT_SOURCE@ toggle
if [ "$(pactl get-source-mute @DEFAULT_SOURCE@)" = "Mute: yes" ]; then
    swayosd-client --custom-icon microphone-sensitivity-muted --custom-message 'Mic Muted'
else
    swayosd-client --custom-icon microphone-sensitivity-high --custom-message 'Mic Unmuted'
fi
