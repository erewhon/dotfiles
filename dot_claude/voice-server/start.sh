#!/bin/bash

# Start the DevVoice Server

SERVICE_NAME="com.devvoice.server"
PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PORT="${DEVVOICE_PORT:-28888}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}▶ Starting DevVoice Server...${NC}"

# Check for Bun
if ! command -v bun &> /dev/null; then
    echo -e "${RED}✗ Bun is not installed${NC}"
    echo "  Install: curl -fsSL https://bun.sh/install | bash"
    exit 1
fi

# Check if already running on the port
if lsof -i :$PORT > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Something is already running on port $PORT${NC}"
    echo "  To restart, use: ./restart.sh"
    exit 0
fi

# macOS LaunchAgent support
if [ "$(uname)" = "Darwin" ] && [ -f "$PLIST_PATH" ]; then
    # Check if already loaded
    if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Service is already loaded${NC}"
        echo "  To restart, use: ./restart.sh"
        exit 0
    fi

    # Load the service
    launchctl load "$PLIST_PATH" 2>/dev/null

    if [ $? -eq 0 ]; then
        sleep 2
        if curl -s -f -X GET http://localhost:$PORT/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ DevVoice server started successfully${NC}"
            echo "  Port: $PORT"
        else
            echo -e "${YELLOW}⚠ Server started but not responding yet${NC}"
            echo "  Check logs: tail -f ~/Library/Logs/devvoice-server.log"
        fi
    else
        echo -e "${RED}✗ Failed to start via LaunchAgent${NC}"
        echo "  Trying direct start..."
    fi
else
    # Direct start (non-macOS or no LaunchAgent)
    echo -e "${YELLOW}▶ Starting server directly...${NC}"
    cd "$SCRIPT_DIR"

    # Start in background
    nohup bun run server.ts > /tmp/devvoice-server.log 2>&1 &
    SERVER_PID=$!

    sleep 2

    if curl -s -f -X GET http://localhost:$PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ DevVoice server started successfully${NC}"
        echo "  Port: $PORT"
        echo "  PID: $SERVER_PID"
        echo "  Logs: /tmp/devvoice-server.log"
        echo "  Test: curl http://localhost:$PORT/health"
    else
        echo -e "${RED}✗ Failed to start server${NC}"
        echo "  Check logs: cat /tmp/devvoice-server.log"
        exit 1
    fi
fi
