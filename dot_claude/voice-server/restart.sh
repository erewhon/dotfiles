#!/bin/bash

# Restart the DevVoice Server

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}▶ Restarting DevVoice Server...${NC}"

# Stop the server
"$SCRIPT_DIR/stop.sh"

# Wait a moment
sleep 2

# Start the server
"$SCRIPT_DIR/start.sh"

echo -e "${GREEN}✓ DevVoice server restarted${NC}"
