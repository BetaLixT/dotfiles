#!/bin/bash

# Audio output switcher
#
# On this Lenovo/Intel SOF setup the laptop "Speaker" and "Headphones" live in
# two mutually-exclusive card profiles, so only one of them is ever exposed as a
# sink at a time. WirePlumber tends to pick the Headphones profile when docking,
# which makes the laptop speaker silently disappear from the output list.
#
# This menu hides that quirk: picking Speaker/Headphones switches the card
# profile first, then routes to the right sink. HDMI/dock outputs are listed
# dynamically and just get a plain set-default-sink.

CARD="alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"
SPK_PROFILE="HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)"
HP_PROFILE="HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1, Mic2)"
SPK_SINK="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink"
HP_SINK="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Headphones__sink"

current="$(pactl get-default-sink)"

# Move every active stream onto the new sink so audio follows the switch.
move_streams() {
    local sink="$1"
    pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
        pactl move-sink-input "$id" "$sink" 2>/dev/null
    done
}

select_sink() {
    local sink="$1"
    pactl set-default-sink "$sink" && move_streams "$sink"
}

# A "•" prefix marks whichever output is currently active.
mark() { [ "$1" = "$current" ] && echo "•" || echo " "; }

sink_desc() {
    pactl list sinks | awk -v n="$1" '
        $1=="Name:" {cur=($2==n)}
        cur && $1=="Description:" {sub(/^[^:]*: /,""); print; exit}'
}

# Parallel arrays: labels[i] is what rofi shows, sinks[i] is the matching action.
# An empty sinks[i] means "Speaker"/"Headphones" handled via profile switch.
labels=()
sinks=()

labels+=("$(mark "$SPK_SINK") 🔊  Speaker (laptop)");      sinks+=("__SPK__")
labels+=("$(mark "$HP_SINK") 🎧  Headphones (3.5mm)");     sinks+=("__HP__")

while read -r name; do
    [ -z "$name" ] && continue
    case "$name" in
        "$SPK_SINK"|"$HP_SINK") continue ;;
        *HDMI1*) label="HDMI / DisplayPort 1" ;;
        *HDMI2*) label="HDMI / DisplayPort 2" ;;
        *HDMI3*) label="HDMI / DisplayPort 3" ;;
        *)       label="$(sink_desc "$name")"; [ -z "$label" ] && label="$name" ;;
    esac
    labels+=("$(mark "$name") 🖥️  ${label}")
    sinks+=("$name")
done < <(pactl list short sinks | awk '{print $2}')

chosen="$(printf '%s\n' "${labels[@]}" | rofi -dmenu -p "Audio out")"
[ -z "$chosen" ] && exit 0

# Resolve the picked label back to its action.
for i in "${!labels[@]}"; do
    [ "${labels[$i]}" = "$chosen" ] || continue
    case "${sinks[$i]}" in
        __SPK__) pactl set-card-profile "$CARD" "$SPK_PROFILE"; sleep 0.3; select_sink "$SPK_SINK" ;;
        __HP__)  pactl set-card-profile "$CARD" "$HP_PROFILE";  sleep 0.3; select_sink "$HP_SINK" ;;
        *)       select_sink "${sinks[$i]}" ;;
    esac
    break
done
