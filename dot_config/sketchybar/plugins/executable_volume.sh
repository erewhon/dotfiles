#!/bin/bash
# Output volume. $INFO carries the percentage on volume_change.

source "$CONFIG_DIR/colors.sh"

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"
else
  VOLUME="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
fi
[ -z "$VOLUME" ] && exit 0

COLOR=$FG
case "$VOLUME" in
  [6-9][0-9]|100)   ICON="󰕾" ;;
  [3-5][0-9])       ICON="󰖀" ;;
  [1-9]|[1-2][0-9]) ICON="󰕿" ;;
  *)                ICON="󰖁"; COLOR=$FG_DIM ;;
esac

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="$VOLUME%"
