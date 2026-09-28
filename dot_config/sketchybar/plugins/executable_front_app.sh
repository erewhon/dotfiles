#!/bin/bash
# Name of the focused application. $INFO carries it on front_app_switched.

if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set "$NAME" label="$INFO"
fi
