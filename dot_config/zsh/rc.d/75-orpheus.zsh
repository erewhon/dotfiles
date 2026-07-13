# -*- Mode: sh -*-
# Orpheus TTS: point `orpheus-say` at the local mlx-audio server on macOS.
# The server runs as a launchd LaunchAgent (org.byrnes.orpheus) set up by
# run_onchange_after_40-darwin-orpheus. On Linux, orpheus-say keeps its default
# (the fleet endpoint), so this stays macOS-only.
if [[ "$OSTYPE" == darwin* ]]; then
    export ORPHEUS_URL="http://127.0.0.1:8000"
    export ORPHEUS_MODEL="mlx-community/orpheus-3b-0.1-ft-4bit"
fi
