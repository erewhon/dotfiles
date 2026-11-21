#!/bin/sh
# Copies one file from a herdr machine into this computer's Downloads folder and reveals it.
# Usage: download.sh <machine> <absolute path there>. Prints the local path.
# `hc exec` passes bytes through intact but keeps only the first 8 MB of output,
# so the file comes over in 4 MiB pieces and is checked against the remote cksum.
PATH="$HOME/.local/bin:$PATH"
m=$1 src=$2
remote() { hc exec --on "$m" --timeout 600 -- "$@"; }

sum=$(remote cksum "$src") || { echo "Cannot read $src on $m" >&2; exit 1; }
set -- $sum; crc=$1 size=$2

dir=$(xdg-user-dir DOWNLOAD 2>/dev/null)
{ [ -n "$dir" ] && [ "$dir" != "$HOME" ]; } || dir=$HOME/Downloads
mkdir -p "$dir" || exit 1
name=${src##*/}
case $name in ?*.*) stem=${name%.*} ext=.${name##*.} ;; *) stem=$name ext= ;; esac
dest=$dir/$name n=1
while [ -e "$dest" ] || [ -e "$dest.part" ]; do dest="$dir/$stem ($n)$ext"; n=$((n + 1)); done

tmp=$dest.part
trap 'rm -f "$tmp"' EXIT
: > "$tmp" || exit 1
chunk=4194304 i=0
while [ $((i * chunk)) -lt "$size" ]; do
  remote sh -c 'dd if="$1" bs="$2" skip="$3" count=1 2>/dev/null' dd "$src" "$chunk" "$i" >> "$tmp" \
    || { echo "Transfer from $m stopped at $((i * chunk)) of $size bytes" >&2; exit 1; }
  i=$((i + 1))
done
set -- $(cksum < "$tmp")
[ "$1" = "$crc" ] && [ "$2" = "$size" ] \
  || { echo "Checksum mismatch: got $2 bytes, expected $size (the file may have changed while copying)" >&2; exit 1; }
mv "$tmp" "$dest" || exit 1
printf '%s\n' "$dest"
sh "$(dirname "$0")/reveal.sh" "$dest"
