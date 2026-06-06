#!/bin/bash
# Stop all Goose components forcefully

echo "Stopping all Goose processes..."

# Get the PID of this script to exclude it
SCRIPT_PID=$$

# Stop goosed server processes first (more specific)
pkill -9 -f "goosed" 2>/dev/null && echo "✓ Stopped goosed server processes"

# Stop goose CLI processes (exclude this script)
ps aux | grep -E "[g]oose" | grep -v "stop-goose" | grep -v "grep" | awk '{print $2}' | xargs -r kill -9 2>/dev/null && echo "✓ Stopped goose CLI processes"

# Stop Electron/desktop UI processes
pkill -9 -f "[G]oose" 2>/dev/null && echo "✓ Stopped Goose desktop UI"
ps aux | grep -E "[e]lectron.*goose" | awk '{print $2}' | xargs -r kill -9 2>/dev/null && echo "✓ Stopped Electron processes"

# Stop any Node.js processes related to Goose UI
ps aux | grep -E "[u]i/desktop" | awk '{print $2}' | xargs -r kill -9 2>/dev/null && echo "✓ Stopped UI development processes"

# Stop any pnpm dev servers
ps aux | grep -E "[p]npm.*dev" | awk '{print $2}' | xargs -r kill -9 2>/dev/null && echo "✓ Stopped pnpm dev servers"

# Stop any cargo run processes related to goose
ps aux | grep -E "[c]argo run.*goose" | awk '{print $2}' | xargs -r kill -9 2>/dev/null && echo "✓ Stopped cargo run processes"

# Stop any MCP server processes
#ps aux | grep -E "[m]cp-server" | awk '{print $2}' | xargs -r kill -9 2>/dev/null && echo "✓ Stopped MCP server processes"

# Wait a moment for processes to terminate
sleep 1

# Check if any Goose processes are still running
REMAINING=$(ps aux | grep -E "goose|goosed|Goose" | grep -v grep | grep -v "stop-goose")

if [ -z "$REMAINING" ]; then
    echo ""
    echo "✅ All Goose processes stopped successfully"
else
    echo ""
    echo "⚠️  Some processes may still be running:"
    echo "$REMAINING"
    echo ""
    echo "You may need to manually kill these processes or restart your system."
fi

echo ""
echo "You can now restart Goose with the new build."

# Made with Bob
