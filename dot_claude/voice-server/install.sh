#!/bin/bash

# DevVoice Server Installation Script
# Installs the voice server as a macOS LaunchAgent or systemd service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVICE_NAME="com.devvoice.server"
PORT="${DEVVOICE_PORT:-28888}"
ENV_FILE="$HOME/.env"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     DevVoice Server Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check for Bun
echo -e "${YELLOW}▶ Checking prerequisites...${NC}"
if ! command -v bun &> /dev/null; then
    echo -e "${RED}✗ Bun is not installed${NC}"
    echo "  Please install Bun first:"
    echo "  curl -fsSL https://bun.sh/install | bash"
    exit 1
fi
BUN_PATH=$(which bun)
echo -e "${GREEN}✓ Bun is installed at $BUN_PATH${NC}"

# Check for ElevenLabs configuration
echo -e "${YELLOW}▶ Checking ElevenLabs configuration...${NC}"
ELEVENLABS_CONFIGURED=false
if [ -f "$ENV_FILE" ] && grep -q "ELEVENLABS_API_KEY=" "$ENV_FILE"; then
    API_KEY=$(grep "ELEVENLABS_API_KEY=" "$ENV_FILE" | cut -d'=' -f2)
    if [ "$API_KEY" != "your_api_key_here" ] && [ -n "$API_KEY" ]; then
        echo -e "${GREEN}✓ ElevenLabs API key configured${NC}"
        ELEVENLABS_CONFIGURED=true
    fi
fi

if [ "$ELEVENLABS_CONFIGURED" = false ]; then
    echo -e "${YELLOW}⚠ ElevenLabs API key not configured${NC}"
    echo "  Voice notifications will be disabled until configured."
    echo "  To enable AI voices, add your ElevenLabs API key to ~/.env:"
    echo "    echo 'ELEVENLABS_API_KEY=your_api_key_here' >> ~/.env"
    echo "  Get a key at: https://elevenlabs.io"
    echo
fi

# Platform-specific installation
if [ "$(uname)" = "Darwin" ]; then
    # macOS LaunchAgent installation
    PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
    LOG_PATH="$HOME/Library/Logs/devvoice-server.log"

    # Check for existing installation
    if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}⚠ DevVoice server is already installed${NC}"
        read -p "Do you want to reinstall? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}▶ Stopping existing service...${NC}"
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
            echo -e "${GREEN}✓ Existing service stopped${NC}"
        else
            echo "Installation cancelled"
            exit 0
        fi
    fi

    # Create LaunchAgent plist
    echo -e "${YELLOW}▶ Creating LaunchAgent configuration...${NC}"
    mkdir -p "$HOME/Library/LaunchAgents"

    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${SERVICE_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${BUN_PATH}</string>
        <string>run</string>
        <string>${SCRIPT_DIR}/server.ts</string>
    </array>

    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>${LOG_PATH}</string>

    <key>StandardErrorPath</key>
    <string>${LOG_PATH}</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${HOME}</string>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME}/.bun/bin</string>
        <key>DEVVOICE_PORT</key>
        <string>${PORT}</string>
    </dict>
</dict>
</plist>
EOF

    echo -e "${GREEN}✓ LaunchAgent configuration created${NC}"

    # Load the LaunchAgent
    echo -e "${YELLOW}▶ Starting DevVoice server service...${NC}"
    launchctl load "$PLIST_PATH" 2>/dev/null || {
        echo -e "${RED}✗ Failed to load LaunchAgent${NC}"
        echo "  Try manually: launchctl load $PLIST_PATH"
        exit 1
    }

    # Wait for server to start
    sleep 2

    # Test the server
    echo -e "${YELLOW}▶ Testing DevVoice server...${NC}"
    if curl -s -f -X GET http://localhost:$PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ DevVoice server is running${NC}"

        # Send test notification (voice disabled to avoid surprise)
        echo -e "${YELLOW}▶ Sending test notification...${NC}"
        curl -s -X POST http://localhost:$PORT/notify \
            -H "Content-Type: application/json" \
            -d '{"message": "DevVoice server installed successfully", "voice_enabled": false}' > /dev/null
        echo -e "${GREEN}✓ Test notification sent${NC}"
    else
        echo -e "${RED}✗ DevVoice server is not responding${NC}"
        echo "  Check logs at: $LOG_PATH"
        exit 1
    fi

    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}     ✓ Installation Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Service Information:${NC}"
    echo "  • Service: $SERVICE_NAME"
    echo "  • Status: Running"
    echo "  • Port: $PORT"
    echo "  • Logs: $LOG_PATH"
    echo "  • Voice: ${ELEVENLABS_CONFIGURED:+ElevenLabs AI}${ELEVENLABS_CONFIGURED:-Disabled}"

else
    # Linux/other: Show manual instructions
    echo -e "${YELLOW}▶ Linux/Other Platform Detected${NC}"
    echo
    echo "To run DevVoice server manually:"
    echo "  cd $SCRIPT_DIR && bun run server.ts"
    echo
    echo "To run as a systemd service, create /etc/systemd/user/devvoice.service:"
    cat << EOF

[Unit]
Description=DevVoice Development Voice Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
ExecStart=$BUN_PATH run server.ts
Restart=on-failure
Environment=HOME=$HOME
Environment=DEVVOICE_PORT=$PORT

[Install]
WantedBy=default.target
EOF

    echo
    echo "Then run:"
    echo "  systemctl --user enable devvoice"
    echo "  systemctl --user start devvoice"
fi

echo
echo -e "${BLUE}Management Commands:${NC}"
echo "  • Status:   ./status.sh"
echo "  • Stop:     ./stop.sh"
echo "  • Start:    ./start.sh"
echo "  • Restart:  ./restart.sh"
echo "  • Uninstall: ./uninstall.sh"

echo
echo -e "${BLUE}Test the server:${NC}"
echo "  curl http://localhost:$PORT/health"
echo "  curl -X POST http://localhost:$PORT/notify \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"message\": \"Hello from DevVoice\"}'"

echo
echo -e "${BLUE}Development Endpoints:${NC}"
echo "  POST /dev/requirement-review - Review requirement fulfillment"
echo "  POST /dev/code-review        - Code review notifications"
echo "  POST /dev/build-status       - Build status updates"
echo "  POST /dev/test-results       - Test result summaries"
echo "  POST /dev/task-complete      - Task completion announcements"
