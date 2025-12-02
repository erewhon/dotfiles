#!/bin/bash

# Stop the DevVoice Server

SERVICE_NAME="com.devvoice.server"
PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
PORT="${DEVVOICE_PORT:-28888}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}▶ Stopping DevVoice Server...${NC}"

# macOS LaunchAgent support
if [ "$(uname)" = "Darwin" ] && launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    launchctl unload "$PLIST_PATH" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ LaunchAgent service stopped${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to unload LaunchAgent${NC}"
    fi
fi

# Kill any remaining processes on the port
if lsof -i :$PORT > /dev/null 2>&1; then
    echo -e "${YELLOW}▶ Cleaning up port $PORT...${NC}"
    lsof -ti :$PORT | xargs kill -9 2>/dev/null
    echo -e "${GREEN}✓ Port $PORT cleared${NC}"
else
    echo -e "${YELLOW}⚠ No process found on port $PORT${NC}"
fi

echo -e "${GREEN}✓ DevVoice server stopped${NC}"
