#!/bin/bash
# Battery level. Hides itself on Macs without a battery.

source "$CONFIG_DIR/colors.sh"

BATT="$(pmset -g batt)"
PERCENTAGE="$(echo "$BATT" | grep -Eo '[0-9]+%' | head -1 | cut -d% -f1)"

if [ -z "$PERCENTAGE" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

COLOR=$FG
case "$PERCENTAGE" in
  9[0-9]|100) ICON="" ;;
  [6-8][0-9]) ICON="" ;;
  [3-5][0-9]) ICON="" ;;
  [1-2][0-9]) ICON=""; COLOR=$WARN ;;
  *)          ICON=""; COLOR=$ALERT ;;
esac

if echo "$BATT" | grep -q 'AC Power'; then
  ICON=""
  COLOR=$GOOD
fi

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COLOR" label="${PERCENTAGE}%"
