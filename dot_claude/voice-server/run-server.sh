#!/usr/bin/env bash
# DevVoice Server Launcher Script
# For direct execution or use with process managers

# Use current user's HOME if not set
export HOME="${HOME:-$(eval echo ~$USER)}"
export PATH="$HOME/.bun/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DEVVOICE_PORT="${DEVVOICE_PORT:-28888}"

# Determine script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$SCRIPT_DIR"
exec bun run server.ts
