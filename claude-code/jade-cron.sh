#!/bin/bash
set -e

# JADE Cron Script - Runs periodic autonomous checks
# This script is invoked by cron every 5 minutes to check for work

LOCKFILE="/tmp/jade-cron.lock"
LOGFILE="/workspace/.jade/cron.log"

# Create log directory if it doesn't exist
mkdir -p /workspace/.jade

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Check if another instance is running
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log "Another JADE cron instance is running (PID: $PID), exiting"
        exit 0
    else
        log "Stale lockfile found, removing"
        rm -f "$LOCKFILE"
    fi
fi

# Create lockfile
echo $$ > "$LOCKFILE"

# Cleanup on exit
cleanup() {
    rm -f "$LOCKFILE"
    log "JADE cron check completed"
}
trap cleanup EXIT

log "=== JADE Autonomous Check Starting ==="

# Change to workspace directory
cd /workspace

# Check if workspace-level CLAUDE.md exists for project-specific overrides
if [ -f ".claude/CLAUDE.md" ]; then
    log "Using workspace-level CLAUDE.md (project-specific)"
    CLAUDE_INSTRUCTIONS=".claude/CLAUDE.md"
else
    log "Using user-level CLAUDE.md (default instructions)"
    CLAUDE_INSTRUCTIONS="/home/node/.claude/CLAUDE.md"
fi

# Run Claude Code with instructions
log "Invoking Claude Code for autonomous check..."
log "Reading instructions from: $CLAUDE_INSTRUCTIONS"

# Run claude with the workspace context
# Claude will read CLAUDE.md for instructions
# Flags:
#   --dangerously-skip-permissions: Allow autonomous tool execution without prompts
#   --non-interactive: Don't wait for user input
#   --yes: Auto-approve actions (if supported)
if claude --workspace /workspace --dangerously-skip-permissions --non-interactive << PROMPT
Read the instructions in $CLAUDE_INSTRUCTIONS and perform your routine autonomous check.

Check for:
1. Any issues or tasks assigned to you
2. Work that needs attention
3. Status updates to provide

If there's work to do, proceed with it. If not, report "No work found" and exit.
PROMPT
then
    log "Claude Code check completed successfully"
else
    log "ERROR: Claude Code check failed with exit code $?"
fi

log "=== JADE Autonomous Check Complete ==="
