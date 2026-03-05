#!/bin/bash

# Clipboard history using cliphist

cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy
