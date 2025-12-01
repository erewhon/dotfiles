#!/bin/bash

# Check status of DevVoice Server

SERVICE_NAME="com.devvoice.server"
PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
LOG_PATH="$HOME/Library/Logs/devvoice-server.log"
ENV_FILE="$HOME/.env"
PORT="${DEVVOICE_PORT:-28888}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     DevVoice Server Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check LaunchAgent (macOS only)
if [ "$(uname)" = "Darwin" ]; then
    echo -e "${BLUE}macOS Service Status:${NC}"
    if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
        PID=$(launchctl list | grep "$SERVICE_NAME" | awk '{print $1}')
        if [ "$PID" != "-" ]; then
            echo -e "  ${GREEN}✓ Service is loaded (PID: $PID)${NC}"
        else
            echo -e "  ${YELLOW}⚠ Service is loaded but not running${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ Service is not loaded (run install.sh for auto-start)${NC}"
    fi
    echo
fi

# Check if server is responding
echo -e "${BLUE}Server Status:${NC}"
if curl -s -f -X GET http://localhost:$PORT/health > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Server is responding on port $PORT${NC}"

    # Get health info
    HEALTH=$(curl -s http://localhost:$PORT/health 2>/dev/null)
    if [ -n "$HEALTH" ]; then
        echo "  Health: $HEALTH" | head -c 200
        echo
    fi
else
    echo -e "  ${RED}✗ Server is not responding on port $PORT${NC}"
fi

# Check port binding
echo
echo -e "${BLUE}Port Status:${NC}"
if lsof -i :$PORT > /dev/null 2>&1; then
    PROCESS=$(lsof -i :$PORT | grep LISTEN | head -1)
    echo -e "  ${GREEN}✓ Port $PORT is in use${NC}"
    echo "  $PROCESS" | awk '{print "  Process: " $1 " (PID: " $2 ")"}'
else
    echo -e "  ${YELLOW}⚠ Port $PORT is not in use${NC}"
fi

# Check ElevenLabs configuration
echo
echo -e "${BLUE}Voice Configuration:${NC}"
if [ -f "$ENV_FILE" ] && grep -q "ELEVENLABS_API_KEY=" "$ENV_FILE"; then
    API_KEY=$(grep "ELEVENLABS_API_KEY=" "$ENV_FILE" | cut -d'=' -f2)
    if [ "$API_KEY" != "your_api_key_here" ] && [ -n "$API_KEY" ]; then
        echo -e "  ${GREEN}✓ ElevenLabs API configured${NC}"
        if grep -q "ELEVENLABS_VOICE_ID=" "$ENV_FILE"; then
            VOICE_ID=$(grep "ELEVENLABS_VOICE_ID=" "$ENV_FILE" | cut -d'=' -f2)
            echo "  Voice ID: $VOICE_ID"
        fi
    else
        echo -e "  ${YELLOW}⚠ ElevenLabs API key not set (voice disabled)${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ No ElevenLabs configuration found${NC}"
    echo "  Add to ~/.env: ELEVENLABS_API_KEY=your_key_here"
fi

# Check logs
echo
echo -e "${BLUE}Recent Logs:${NC}"
if [ -f "$LOG_PATH" ]; then
    echo "  Log file: $LOG_PATH"
    echo "  Last 5 lines:"
    tail -5 "$LOG_PATH" 2>/dev/null | while IFS= read -r line; do
        echo "    $line"
    done
elif [ -f "/tmp/devvoice-server.log" ]; then
    echo "  Log file: /tmp/devvoice-server.log"
    echo "  Last 5 lines:"
    tail -5 "/tmp/devvoice-server.log" 2>/dev/null | while IFS= read -r line; do
        echo "    $line"
    done
else
    echo -e "  ${YELLOW}⚠ No log file found${NC}"
fi

# Show commands
echo
echo -e "${BLUE}Available Commands:${NC}"
echo "  • Start:     ./start.sh"
echo "  • Stop:      ./stop.sh"
echo "  • Restart:   ./restart.sh"
echo "  • Install:   ./install.sh (macOS auto-start)"

echo
echo -e "${BLUE}Development Endpoints:${NC}"
echo "  • POST /notify              - Generic notification"
echo "  • POST /dev/requirement-review - Requirement review results"
echo "  • POST /dev/code-review     - Code review feedback"
echo "  • POST /dev/build-status    - Build status notifications"
echo "  • POST /dev/test-results    - Test result summaries"
echo "  • POST /dev/task-complete   - Task completion"
echo "  • GET  /health              - Health check"

echo
echo -e "${BLUE}Test Commands:${NC}"
echo "  curl http://localhost:$PORT/health"
echo "  curl -X POST http://localhost:$PORT/notify \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"message\": \"Hello from DevVoice\"}'"
