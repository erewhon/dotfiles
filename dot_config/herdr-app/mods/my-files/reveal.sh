#!/bin/sh
# Shows a local file in the file manager (Finder on macOS), selected where that is supported.
f=$1
case $(uname) in
  Darwin) open -R "$f" ;;
  *) (dbus-send --session --dest=org.freedesktop.FileManager1 --type=method_call \
        /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems \
        "array:string:file://$f" string: \
      || xdg-open "$(dirname "$f")") > /dev/null 2>&1 & ;;
esac
exit 0
