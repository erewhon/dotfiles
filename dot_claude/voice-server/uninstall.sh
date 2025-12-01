#!/bin/bash

# Uninstall DevVoice Server

SERVICE_NAME="com.devvoice.server"
PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
LOG_PATH="$HOME/Library/Logs/devvoice-server.log"
PORT="${DEVVOICE_PORT:-28888}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     DevVoice Server Uninstallation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Stop service if running
echo -e "${YELLOW}▶ Stopping DevVoice server...${NC}"
if [ "$(uname)" = "Darwin" ] && launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    launchctl unload "$PLIST_PATH" 2>/dev/null
    echo -e "${GREEN}✓ LaunchAgent service stopped${NC}"
fi

# Kill any remaining processes
if lsof -i :$PORT > /dev/null 2>&1; then
    echo -e "${YELLOW}▶ Cleaning up port $PORT...${NC}"
    lsof -ti :$PORT | xargs kill -9 2>/dev/null
    echo -e "${GREEN}✓ Port $PORT cleared${NC}"
fi

# Remove LaunchAgent plist
if [ -f "$PLIST_PATH" ]; then
    echo -e "${YELLOW}▶ Removing LaunchAgent configuration...${NC}"
    rm -f "$PLIST_PATH"
    echo -e "${GREEN}✓ LaunchAgent configuration removed${NC}"
fi

# Ask about logs
if [ -f "$LOG_PATH" ]; then
    echo
    read -p "Remove log file? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$LOG_PATH"
        echo -e "${GREEN}✓ Log file removed${NC}"
    fi
fi

# Clean up temp files
rm -f /tmp/devvoice-*.mp3 2>/dev/null
rm -f /tmp/devvoice-server.log 2>/dev/null

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     ✓ Uninstallation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo "DevVoice server has been removed."
echo "To reinstall, run: ./install.sh"
