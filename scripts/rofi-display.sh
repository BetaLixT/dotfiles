# An option was passed, so let's check it
if [ "$@" ]
then
    # the output from the selection will be the desciption.  Save that for alerts
    desc="$*"
    # Figure out what the device name is based on the description passed
    device=$(pactl list sinks|grep -C2 -F "Description: $desc"|grep Name|cut -d: -f2|xargs)
    # Try to set the default to the device chosen
    
		case $desc in

			"Laptop")
				xrandr --auto
				;;

			"Caldigit TS3 Dock")
				xrandr --output DP-3 --right-of DP-4 && xrandr --output DP-1 --right-of DP-2 && xrandr --output eDP-1 --off
				;;

			*)
				STATEMENTS
				;;
		esac

else
    echo -en "\x00prompt\x1fSelect Display Mode\n"
    # Get the list of outputs based on the description, which is what makes sense to a human
    # and is what we want to show in the menu
    echo -en 'Caldigit TS3 Dock\nLaptop'
fi
