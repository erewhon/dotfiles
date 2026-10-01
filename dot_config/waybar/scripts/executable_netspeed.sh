#!/bin/bash
# Download and upload rate on the interface that carries the default route.
# Linux port of sketchybar/plugins/netspeed.sh, reading the kernel's byte
# counters from /sys. Waybar runs it every 2 s and reads one JSON line.
#
# Unlike the Mac version it keeps no state file: Waybar starts one copy of
# the script per output, and copies sharing a file would clobber each
# other's previous sample. Instead each run samples the counters twice,
# one second apart.

emit() { printf '{"text":"%s","class":"%s"}\n' "$1" "$2"; }

IFACE="$(ip -o route show default 2>/dev/null | awk 'NR == 1 { print $5 }')"
if [ -z "$IFACE" ]; then
  emit "offline" offline
  exit 0
fi

counters() {
  read -r RX < "/sys/class/net/$IFACE/statistics/rx_bytes" 2>/dev/null
  read -r TX < "/sys/class/net/$IFACE/statistics/tx_bytes" 2>/dev/null
  case "$RX$TX" in
    ''|*[!0-9]*) emit "" ""; exit 0 ;;
  esac
}

counters; P_RX=$RX; P_TX=$TX
sleep 1
counters

# Counters that went backwards (interface reset): no meaningful rate.
if [ "$RX" -lt "$P_RX" ] || [ "$TX" -lt "$P_TX" ]; then
  emit "" ""
  exit 0
fi

rate() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1048576) printf "%.1fM", b / 1048576
    else if (b >= 1024) printf "%dK", b / 1024
    else printf "%dB", b
  }'
}

DOWN="$(rate $((RX - P_RX)))"
UP="$(rate $((TX - P_TX)))"

# Padded to a fixed width so the bar does not shift as the numbers change.
emit "$(printf '󰜮 %6s  󰜷 %6s' "$DOWN" "$UP")" ""
