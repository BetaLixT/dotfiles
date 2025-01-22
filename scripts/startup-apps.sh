i3-msg "workspace 1; exec --no-startup-id alacritty"
sleep 3
i3-msg "workspace 2; exec --no-startup-id /usr/bin/firefox -P default"
i3-msg "workspace 2; exec --no-startup-id /usr/bin/firefox -P TU"
i3-msg "workspace 2; exec --no-startup-id /usr/bin/firefox -P nyvcap"
i3-msg "workspace 2; layout tabbed"
sleep 3
