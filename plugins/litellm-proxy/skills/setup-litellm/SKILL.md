---
name: setup-litellm
description: >
  Install and configure LiteLLM proxy for Claude Code. Guides the user through
  installation (pip, pipx, or Docker), initial configuration, starting the proxy,
  and verifying connectivity. Handles both local and remote setups.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Setup LiteLLM Proxy

This skill helps install, configure, and start a LiteLLM proxy for use with Claude Code. LiteLLM acts as an AI gateway that provides a unified interface to 100+ LLM APIs with cost tracking, load balancing, and observability.

## When to Use This Skill

- User wants to set up LiteLLM proxy for the first time
- User asks how to install LiteLLM
- User wants to start or restart the proxy
- Proxy is installed but not running (detected by session-start hook)
- User mentions "llm proxy", "litellm", "AI gateway"

## Interactive Setup Flow

### Step 1: Check Current State

Before anything, assess what's already in place:

```bash
# Check if litellm is installed
command -v litellm && litellm --version
# Or as Python module
python3 -m litellm --version 2>/dev/null
# Check for Docker
docker image ls | grep litellm 2>/dev/null
# Check if already running
curl -s http://localhost:4000/health 2>/dev/null
# Check for existing config
ls -la ~/.litellm/config.yaml 2>/dev/null
```

### Step 2: Prompt User for Installation Method

Ask the user which installation method they prefer:

**Option A: pip/pipx (Recommended for most users)**

```bash
# Using pip
pip install 'litellm[proxy]'

# Using pipx (isolated environment, recommended)
pipx install 'litellm[proxy]'
```

**Option B: Docker (Recommended for production)**

```bash
# Pull the image
docker pull ghcr.io/berriai/litellm:main-latest

# Run with a config file
docker run -d \
  --name litellm-proxy \
  -p 4000:4000 \
  -v ~/.litellm/config.yaml:/app/config.yaml \
  -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml
```

**Option C: Docker Compose (Recommended for observability stack)**

```yaml
# docker-compose.yaml
version: "3.9"
services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    ports:
      - "4000:4000"
    volumes:
      - ./config.yaml:/app/config.yaml
    env_file:
      - .env
    command: --config /app/config.yaml
```

### Step 3: Create Configuration

Ask the user which providers they need, then generate a config:

```bash
# Create config directory
mkdir -p ~/.litellm

# Copy template
cp "${CLAUDE_PLUGIN_ROOT}/config/litellm_config.template.yaml" ~/.litellm/config.yaml
```

Then customize based on user's answers. See the **configure-providers** skill for detailed provider setup.

### Step 4: Set Master Key

The master key authenticates requests to the proxy:

```bash
# Generate a random master key
export LITELLM_MASTER_KEY="sk-litellm-$(openssl rand -hex 16)"
echo "export LITELLM_MASTER_KEY='$LITELLM_MASTER_KEY'" >> ~/.bashrc
# Or ~/.zshrc for zsh users
```

Add to the LiteLLM config:

```yaml
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
```

### Step 5: Start the Proxy

```bash
# Foreground (for testing)
litellm --config ~/.litellm/config.yaml --port 4000

# Background
litellm --config ~/.litellm/config.yaml --port 4000 &

# With Docker
docker start litellm-proxy
```

### Step 6: Verify Health

```bash
# Check health endpoint
curl http://localhost:4000/health

# Test with a simple completion
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-sonnet-4-20250514",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }'
```

### Step 7: Configure Plugin Settings

Create or update the plugin settings so the session-start hook auto-configures Claude Code:

```yaml
# In ~/.claude/plugins.settings.yaml
litellm-proxy:
  enabled: true
  mode: local
  proxy_host: "http://localhost"
  proxy_port: "4000"
  master_key: "${LITELLM_MASTER_KEY}"
  config_path: "~/.litellm/config.yaml"
  anthropic_pass_through: true
```

### Step 8: Verify Claude Code Integration

After setup, restart Claude Code (or start a new session). The session-start hook will:

1. Detect the running proxy
2. Set `ANTHROPIC_BASE_URL` to point at the proxy
3. Set `ANTHROPIC_AUTH_TOKEN` if a master key is configured

You can verify by checking:

```bash
# Check settings.local.json
cat ~/.claude/settings.local.json | jq '.env.ANTHROPIC_BASE_URL'
```

## Troubleshooting

### Proxy won't start

```bash
# Check if port is in use
lsof -i :4000
# Check logs
litellm --config ~/.litellm/config.yaml --detailed_debug
```

### Authentication errors

```bash
# Verify master key is set
echo $LITELLM_MASTER_KEY
# Test with explicit key
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/health
```

### Config validation

```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('$HOME/.litellm/config.yaml'))"
```

## Running as a System Service (Optional)

For always-on operation, create a systemd service:

```bash
# Create service file
sudo tee /etc/systemd/system/litellm.service << 'EOF'
[Unit]
Description=LiteLLM Proxy
After=network.target

[Service]
Type=simple
User=$USER
Environment="LITELLM_MASTER_KEY=your-key-here"
Environment="ANTHROPIC_API_KEY=your-key-here"
ExecStart=/usr/local/bin/litellm --config /home/$USER/.litellm/config.yaml --port 4000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable litellm
sudo systemctl start litellm
```

Or with launchd on macOS:

```bash
cat > ~/Library/LaunchAgents/com.litellm.proxy.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.litellm.proxy</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/litellm</string>
    <string>--config</string>
    <string>/Users/YOU/.litellm/config.yaml</string>
    <string>--port</string>
    <string>4000</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.litellm.proxy.plist
```
