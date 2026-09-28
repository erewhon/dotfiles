#!/bin/bash
# Which interface carries the default route, and its address.
# Shows the address rather than the Wi-Fi name: recent macOS versions hide the
# network name from scripts unless location access is granted.

source "$CONFIG_DIR/colors.sh"

IFACE="$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')"

if [ -z "$IFACE" ]; then
  sketchybar --set "$NAME" icon="󰖪" icon.color="$ALERT" label="offline"
  exit 0
fi

WIFI_DEV="$(networksetup -listallhardwareports 2>/dev/null |
  awk '/Hardware Port: (Wi-Fi|AirPort)/ { getline; print $2 }')"

if [ "$IFACE" = "$WIFI_DEV" ]; then
  ICON="󰖩"
else
  ICON="󰈀"
fi

ADDR="$(ipconfig getifaddr "$IFACE" 2>/dev/null)"
sketchybar --set "$NAME" icon="$ICON" icon.color="$FG" label="${ADDR:-$IFACE}"
