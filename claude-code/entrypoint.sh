#!/bin/bash
set -e

echo "=== JADE Entrypoint ==="

# Load .env file if it exists
if [ -f /app/.env ]; then
    echo "Loading environment variables from /app/.env..."
    export $(grep -v '^#' /app/.env | grep -v '^$' | xargs)
fi

# Generate MCP settings.json
echo "Generating MCP settings.json..."
mkdir -p /home/node/.claude

# Build MCP servers JSON
MCP_SERVERS="{"
FIRST=true

# Add Slack MCP if token is provided
if [ -n "$SLACK_BOT_TOKEN" ] && [ -n "$SLACK_TEAM_ID" ]; then
    echo "  - Configuring Slack MCP server"
    if [ "$FIRST" = false ]; then
        MCP_SERVERS="$MCP_SERVERS,"
    fi
    MCP_SERVERS="$MCP_SERVERS
    \"slack\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@zencoderai/slack-mcp-server\"],
      \"env\": {
        \"SLACK_BOT_TOKEN\": \"$SLACK_BOT_TOKEN\",
        \"SLACK_TEAM_ID\": \"$SLACK_TEAM_ID\"
      }
    }"
    FIRST=false
fi

# Add GitHub MCP if token is provided
if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "  - Configuring GitHub MCP server"
    if [ "$FIRST" = false ]; then
        MCP_SERVERS="$MCP_SERVERS,"
    fi
    MCP_SERVERS="$MCP_SERVERS
    \"github\": {
      \"command\": \"/usr/local/bin/github-mcp-server\",
      \"args\": [\"stdio\"],
      \"env\": {
        \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$GITHUB_PERSONAL_ACCESS_TOKEN\"
      }
    }"
    FIRST=false
fi

MCP_SERVERS="$MCP_SERVERS
  }"

# Write settings.json with full autonomy settings
cat > /home/node/.claude/settings.json <<EOF
{
  "mcpServers": $MCP_SERVERS,
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
      "Bash(*)",
      "Edit(*)",
      "Read(*)",
      "Write(*)",
      "WebFetch(*)"
    ],
    "deny": []
  },
  "enableAllProjectMcpServers": true,
  "sandbox": {
    "enabled": false,
    "autoAllowBashIfSandboxed": true
  },
  "env": {
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_COST_WARNINGS": "1",
    "DISABLE_ERROR_REPORTING": "1"
  }
}
EOF

echo "MCP settings.json generated at /home/node/.claude/settings.json with full autonomy configuration"
echo ""
echo "Available MCP servers:"
if [ -n "$SLACK_BOT_TOKEN" ] && [ -n "$SLACK_TEAM_ID" ]; then
    echo "  ✓ Slack"
fi
if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "  ✓ GitHub"
fi
echo ""

# Configure cron for autonomous checks
# Default to 5 minute intervals if CHECK_INTERVAL not set
CHECK_INTERVAL=${CHECK_INTERVAL:-300}
CRON_SCHEDULE="*/${CHECK_INTERVAL} * * * *"

# If CHECK_INTERVAL is in seconds and >= 60, convert to minutes
if [ "$CHECK_INTERVAL" -ge 60 ]; then
    CRON_MINUTES=$((CHECK_INTERVAL / 60))
    if [ "$CRON_MINUTES" -le 59 ]; then
        CRON_SCHEDULE="*/$CRON_MINUTES * * * *"
    else
        # If > 59 minutes, default to every 5 minutes
        CRON_SCHEDULE="*/5 * * * *"
    fi
fi

echo "Configuring cron for autonomous checks..."
echo "Schedule: Every $((CHECK_INTERVAL / 60)) minutes"

# Create crontab entry (run as root since we need to write to /etc/cron.d/)
# Switch back to root temporarily
if [ "$(id -u)" != "0" ]; then
    # We're already running as node user, need to use sudo or run cron differently
    # For now, write to user's crontab
    (crontab -l 2>/dev/null || true; echo "$CRON_SCHEDULE /usr/local/bin/jade-cron.sh >> /workspace/.jade/cron.log 2>&1") | crontab -
    echo "  ✓ Crontab configured for user 'node'"
else
    # Running as root, create system cron job
    echo "$CRON_SCHEDULE node /usr/local/bin/jade-cron.sh >> /workspace/.jade/cron.log 2>&1" > /etc/cron.d/jade-check
    chmod 0644 /etc/cron.d/jade-check
    echo "  ✓ System cron job created"
fi

# Start cron daemon in background
echo "Starting cron daemon..."
sudo service cron start || cron
echo "  ✓ Cron daemon started"
echo ""

# Execute the command passed to the container
exec "$@"
