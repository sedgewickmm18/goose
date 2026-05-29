#!/usr/bin/env bash
# Smart start script for Goose
# Detects if rebuild is needed, rebuilds if necessary, and starts the UI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Checking if rebuild is needed...${NC}"

# Check if binaries exist
GOOSED_BIN="./target/release/goosed"
GOOSE_CLI_BIN="./target/release/goose"
UI_GOOSED_BIN="./ui/desktop/src/bin/goosed"
UI_GOOSE_CLI_BIN="./ui/desktop/src/bin/goose"

NEEDS_BUILD=false

# Check if release binaries exist
if [ ! -f "$GOOSED_BIN" ] || [ ! -f "$GOOSE_CLI_BIN" ]; then
    echo -e "${YELLOW}⚠️  Release binaries not found${NC}"
    NEEDS_BUILD=true
fi

# Check if UI binaries exist
if [ ! -f "$UI_GOOSED_BIN" ] || [ ! -f "$UI_GOOSE_CLI_BIN" ]; then
    echo -e "${YELLOW}⚠️  UI binaries not found${NC}"
    NEEDS_BUILD=true
fi

# Check if source files are newer than binaries
if [ "$NEEDS_BUILD" = false ]; then
    # Find newest Rust source file
    NEWEST_SOURCE=$(find crates -name "*.rs" -o -name "Cargo.toml" | xargs ls -t 2>/dev/null | head -1)
    
    if [ -n "$NEWEST_SOURCE" ] && [ "$NEWEST_SOURCE" -nt "$GOOSED_BIN" ]; then
        echo -e "${YELLOW}⚠️  Source files newer than binaries${NC}"
        NEEDS_BUILD=true
    fi
fi

# Check if UI binaries are older than release binaries
if [ "$NEEDS_BUILD" = false ]; then
    if [ "$GOOSED_BIN" -nt "$UI_GOOSED_BIN" ] || [ "$GOOSE_CLI_BIN" -nt "$UI_GOOSE_CLI_BIN" ]; then
        echo -e "${YELLOW}⚠️  Release binaries newer than UI binaries${NC}"
        NEEDS_BUILD=true
    fi
fi

# Build if needed
if [ "$NEEDS_BUILD" = true ]; then
    echo -e "${BLUE}🔨 Building Goose...${NC}"
    cargo build --release
    
    echo -e "${BLUE}📦 Copying binaries to UI...${NC}"
    mkdir -p ./ui/desktop/src/bin
    cp -p "$GOOSED_BIN" ./ui/desktop/src/bin/
    cp -p "$GOOSE_CLI_BIN" ./ui/desktop/src/bin/
    
    echo -e "${BLUE}📝 Generating OpenAPI schema...${NC}"
    cargo run -p goose-server --bin generate_schema
    
    echo -e "${GREEN}✅ Build complete${NC}"
else
    echo -e "${GREEN}✅ Binaries are up to date${NC}"
fi

# Start the UI
echo -e "${BLUE}🚀 Starting Goose UI...${NC}"
cd ui/desktop
pnpm install
pnpm run start-gui

# Made with Bob
