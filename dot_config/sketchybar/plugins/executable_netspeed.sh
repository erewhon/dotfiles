#!/bin/bash
# Download and upload rate on the interface that carries the default route.
# Reads the kernel's byte counters and compares them with the previous run,
# so it needs no extra tools. Runs every 2 s (update_freq in sketchybarrc).

source "$CONFIG_DIR/colors.sh"

STATE="${TMPDIR:-/tmp}/sketchybar-netspeed"

IFACE="$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')"
if [ -z "$IFACE" ]; then
  rm -f "$STATE"
  sketchybar --set "$NAME" label="offline" label.color="$FG_DIM"
  exit 0
fi

# Link-level row of netstat. Columns end with:
#   ... Ibytes Opkts Oerrs Obytes Coll
# Counted from the end because the Address column is empty on some interfaces.
read -r RX TX <<EOF
$(netstat -I "$IFACE" -b 2>/dev/null | awk '$3 ~ /^<Link/ { print $(NF-4), $(NF-1); exit }')
EOF
case "$RX$TX" in
  ''|*[!0-9]*) exit 0 ;;
esac

NOW="$(date +%s)"
P_IFACE=""; P_TIME=0; P_RX=0; P_TX=0
[ -r "$STATE" ] && read -r P_IFACE P_TIME P_RX P_TX < "$STATE"
echo "$IFACE $NOW $RX $TX" > "$STATE"

DT=$((NOW - P_TIME))
# First run, interface change, a long sleep, or counters that went backwards:
# there is no meaningful rate yet.
if [ "$P_IFACE" != "$IFACE" ] || [ "$DT" -le 0 ] || [ "$DT" -gt 30 ] ||
   [ "$RX" -lt "$P_RX" ] || [ "$TX" -lt "$P_TX" ]; then
  exit 0
fi

rate() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1048576) printf "%.1fM", b / 1048576
    else if (b >= 1024) printf "%dK", b / 1024
    else printf "%dB", b
  }'
}

DOWN="$(rate $(( (RX - P_RX) / DT )))"
UP="$(rate $(( (TX - P_TX) / DT )))"

# Padded to a fixed width so the bar does not shift as the numbers change.
LABEL="$(printf '󰜮 %6s  󰜷 %6s' "$DOWN" "$UP")"
sketchybar --set "$NAME" label="$LABEL" label.color="$FG"
