# Omarchy (Arch + Hyprland) integration. No-op everywhere else.
#
# Omarchy only wires up bash: its rc chain sets OMARCHY_PATH, puts mise's
# command wrappers first on PATH and activates mise. The agent CLIs (claude,
# pi, codex, opencode), gh, node and uv all come from mise there, so a zsh
# without this file cannot find or auto-update them.
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] || return 0

# OMARCHY_PATH + PATH. The file is plain POSIX sh. It runs after ~/.zshenv on
# purpose: it moves mise's wrapper directory back to the front of PATH.
emulate sh -c 'source /usr/share/omarchy/default/bash/env-bootstrap'

if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# gh and friends open URLs through this, detached from the terminal.
export BROWSER="${BROWSER:-omarchy-launch-browser}"

# `open` as on macOS.
if ! command -v open &> /dev/null; then
    open() { ( xdg-open "$@" > /dev/null 2>&1 & ) }
fi

# The handful of Omarchy bash aliases worth keeping in zsh.
alias h=herdr
alias mup='MISE_MINIMUM_RELEASE_AGE=0 mise up'
