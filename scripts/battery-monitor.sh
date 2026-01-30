#!/bin/bash

THRESHOLD=20
CRITICAL=10


BATTERY=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)

if [[ "$STATUS" == "Discharging" && -n "$BATTERY" ]]; then
		if (( BATTERY <= CRITICAL )); then
				notify-send -u critical "Battery Critical!" "${BATTERY}% - Plug in now!"
		elif (( BATTERY <= THRESHOLD )); then
				notify-send -u critical "Battery Low" "${BATTERY}% remaining"
		fi
fi
