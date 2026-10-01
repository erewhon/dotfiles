#!/bin/sh
# Launch JetBrains Toolbox from wherever it was installed: PATH, the
# self-updating copy under ~/.local/share, or the Flatpak.
for cmd in jetbrains-toolbox "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    exec setsid "$cmd" >/dev/null 2>&1
  fi
done
if command -v flatpak >/dev/null 2>&1 && flatpak info com.jetbrains.Toolbox >/dev/null 2>&1; then
  exec setsid flatpak run com.jetbrains.Toolbox >/dev/null 2>&1
fi
notify-send -a Waybar "JetBrains Toolbox" "Not installed on this machine" 2>/dev/null
exit 1
