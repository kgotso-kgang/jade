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

# Write settings.json
cat > /home/node/.claude/settings.json <<EOF
{
  "mcpServers": $MCP_SERVERS
}
EOF

echo "MCP settings.json generated at /home/node/.claude/settings.json"
echo ""
echo "Available MCP servers:"
if [ -n "$SLACK_BOT_TOKEN" ] && [ -n "$SLACK_TEAM_ID" ]; then
    echo "  ✓ Slack"
fi
if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "  ✓ GitHub"
fi
echo ""

# Execute the command passed to the container
exec "$@"
