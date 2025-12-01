# DevVoice Server

A development-focused voice notification server using ElevenLabs TTS. Adapted from [Daniel Miessler's PAIVoice](https://github.com/danielmiessler/Personal_AI_Infrastructure).

## Features

- **Voice Notifications**: Text-to-speech using ElevenLabs API
- **Development Skills**: Specialized endpoints for common dev workflows
- **Cross-Platform**: Works on macOS and Linux
- **Auto-Start**: LaunchAgent support for macOS

## Quick Start

```bash
# Install Bun if not already installed
curl -fsSL https://bun.sh/install | bash

# Start the server
./start.sh

# Check status
./status.sh

# Test notification
curl -X POST http://localhost:28888/notify \
  -H 'Content-Type: application/json' \
  -d '{"message": "Hello from DevVoice"}'
```

## Configuration

Add your ElevenLabs API key to `~/.env`:

```bash
ELEVENLABS_API_KEY=your_api_key_here
ELEVENLABS_VOICE_ID=optional_custom_voice_id
ELEVENLABS_MODEL=eleven_multilingual_v2
DEVVOICE_PORT=28888
```

Get an API key at [elevenlabs.io](https://elevenlabs.io).

## Endpoints

### Generic Notification

```bash
POST /notify
{
  "title": "Notification Title",
  "message": "Your message here",
  "voice_enabled": true,
  "voice_id": "optional_voice_id"
}
```

### Requirement Review

Report whether changes fulfill requirements:

```bash
POST /dev/requirement-review
{
  "verdict": "pass|partial|fail",
  "summary": "All requirements met",
  "requirements": [
    {"name": "Feature X", "met": true},
    {"name": "Feature Y", "met": false}
  ]
}
```

### Code Review

Report code review feedback:

```bash
POST /dev/code-review
{
  "approval": "approved|rejected",
  "summary": "Code looks good",
  "issues": [
    {"severity": "warning", "message": "Consider refactoring"}
  ]
}
```

### Build Status

Report build completion:

```bash
POST /dev/build-status
{
  "status": "success|failed|running",
  "project": "my-project",
  "duration": "2m 30s",
  "errors": [],
  "warnings": []
}
```

### Test Results

Report test execution results:

```bash
POST /dev/test-results
{
  "passed": 42,
  "failed": 0,
  "skipped": 2,
  "total": 44,
  "duration": "15s",
  "suite": "Unit Tests"
}
```

### Task Completion

Announce task completion:

```bash
POST /dev/task-complete
{
  "task": "Database migration",
  "status": "completed",
  "details": "All tables updated successfully"
}
```

### Health Check

```bash
GET /health
```

## Management Scripts

| Script | Description |
|--------|-------------|
| `start.sh` | Start the server |
| `stop.sh` | Stop the server |
| `restart.sh` | Restart the server |
| `status.sh` | Check server status |
| `install.sh` | Install as auto-start service |
| `uninstall.sh` | Remove auto-start service |
| `run-server.sh` | Direct server execution |

## Integration Examples

### Claude Code Hook

Add to your Claude Code hooks to announce task completion:

```python
# In your hook script
import requests

def announce_completion(message):
    try:
        requests.post(
            "http://localhost:28888/dev/task-complete",
            json={"task": message, "status": "completed"},
            timeout=5
        )
    except:
        pass  # Don't fail if voice server is down
```

### CI/CD Integration

```bash
# After build completion
curl -X POST http://localhost:28888/dev/build-status \
  -H 'Content-Type: application/json' \
  -d "{\"status\": \"$BUILD_STATUS\", \"project\": \"$PROJECT_NAME\"}"
```

### Git Hook

```bash
# post-commit hook
curl -X POST http://localhost:28888/dev/task-complete \
  -H 'Content-Type: application/json' \
  -d '{"task": "Git commit", "status": "completed"}'
```

## Troubleshooting

### Server not responding

1. Check if server is running: `./status.sh`
2. Check logs: `tail -f /tmp/devvoice-server.log`
3. Verify port is free: `lsof -i :28888`

### No voice output

1. Verify ElevenLabs API key in `~/.env`
2. Check API key is valid at [elevenlabs.io](https://elevenlabs.io)
3. Ensure audio player is available (`mpv` on Linux, `afplay` on macOS)

### macOS LaunchAgent issues

```bash
# Reload service
launchctl unload ~/Library/LaunchAgents/com.devvoice.server.plist
launchctl load ~/Library/LaunchAgents/com.devvoice.server.plist

# Check logs
tail -f ~/Library/Logs/devvoice-server.log
```

## License

Adapted from PAIVoice by Daniel Miessler. See original project for license terms.
