#!/usr/bin/env bash
# ============================================================
# install.sh — One-command OpenCode + OpenRouter setup for Termux
# ============================================================
# Usage:
#   pkg install git -y
#   git clone https://github.com/Liaquatali123/opencode-termux.git
#   cd opencode-termux
#   bash install.sh
#
# What it does:
#   1. Installs Node.js / npm (if missing)
#   2. Installs OpenCode globally via npm
#   3. Creates ~/.config/opencode/ with config + AGENTS.md
#   4. Installs wrapper at /usr/local/bin/opencode
#   5. Helps you set up the OpenRouter API key
#   6. Verifies everything works
# ============================================================

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()   { echo -e "${RED}[ERR]${NC}   $1"; }

# ============================================================
echo -e "\n${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    OpenCode + OpenRouter Termux Installer    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}\n"

# --- 1. Check Termux ---
if [ ! -d "/data/data/com.termux" ] && [ ! -f "/data/data/com.termux/files/usr/bin/pkg" ]; then
    warn "This script is designed for Termux on Android."
    warn "Continuing anyway — some paths may differ."
fi

# --- 2. Install Node.js + npm ---
info "Checking Node.js..."
if command -v node &>/dev/null; then
    ok "Node.js $(node -v) already installed"
else
    info "Installing Node.js..."
    pkg update -y && pkg install nodejs -y
    ok "Node.js $(node -v) installed"
fi

# --- 3. Install OpenCode ---
info "Checking OpenCode..."
if command -v opencode &>/dev/null && [[ "$(opencode --version 2>/dev/null)" ]]; then
    ok "OpenCode $(opencode --version) already installed"
else
    info "Installing OpenCode globally via npm..."
    npm install -g opencode-ai
    ok "OpenCode $(opencode --version) installed"
fi

# --- 4. Create config directory ---
info "Setting up config directory..."
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

# --- 5. Copy opencode.json ---
if [ -f "$REPO_DIR/configs/opencode.json" ]; then
    cp "$REPO_DIR/configs/opencode.json" "$OPENCODE_CONFIG_DIR/opencode.json"
    # Replace $HOME placeholder with actual home path
    sed -i "s|\$HOME|$HOME|g" "$OPENCODE_CONFIG_DIR/opencode.json"
    ok "Config copied: $OPENCODE_CONFIG_DIR/opencode.json"
else
    err "configs/opencode.json not found in repo!"
    exit 1
fi

# --- 6. Copy AGENTS.md ---
if [ -f "$REPO_DIR/AGENTS.md" ]; then
    cp "$REPO_DIR/AGENTS.md" "$OPENCODE_CONFIG_DIR/AGENTS.md"
    ok "AGENTS.md copied"
fi

# --- 7. Install wrapper ---
info "Installing opencode wrapper..."
WRAPPER_SRC="$REPO_DIR/scripts/opencode-wrapper.sh"
WRAPPER_DST="/usr/local/bin/opencode"

# The wrapper references a shared API key file.
# We need to make sure the real binary exists first.
OPENCODE_REAL="/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe"
if [ ! -f "$OPENCODE_REAL" ]; then
    # Find the actual binary
    OPENCODE_REAL=$(find /usr -name "opencode.exe" -path "*/opencode-ai/*" 2>/dev/null | head -1)
    if [ -z "$OPENCODE_REAL" ]; then
        err "Cannot find opencode binary! npm install may have failed."
        exit 1
    fi
fi

# Update the wrapper with the correct real binary path
sed "s|/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe|$OPENCODE_REAL|g" \
    "$WRAPPER_SRC" > /tmp/opencode-wrapper-tmp

if [ -f "$WRAPPER_DST" ] && [ ! -L "$WRAPPER_DST" ]; then
    # Backup existing non-symlink wrapper
    cp "$WRAPPER_DST" "$WRAPPER_DST.bak.$(date +%s)"
    info "Backed up existing wrapper"
fi

cp /tmp/opencode-wrapper-tmp "$WRAPPER_DST"
chmod +x "$WRAPPER_DST"
rm -f /tmp/opencode-wrapper-tmp
ok "Wrapper installed: $WRAPPER_DST"

# --- 8. Create shared API key directory ---
SHARED_KEY_DIR="/storage/emulated/0/Download/ai_openrouter/configs"
mkdir -p "$SHARED_KEY_DIR"

if [ ! -f "$SHARED_KEY_DIR/api_key.json" ]; then
    info "Shared API key file not found at $SHARED_KEY_DIR/api_key.json"
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  OpenRouter API Key Setup${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Get your free API key at: https://openrouter.ai/keys"
    echo ""
    read -r -p "Paste your OpenRouter API key (sk-or-...): " USER_KEY
    if [ -n "$USER_KEY" ]; then
        echo "{\"key\": \"$USER_KEY\", \"saved\": \"$(date -Iseconds)\"}" > "$SHARED_KEY_DIR/api_key.json"
        ok "API key saved to $SHARED_KEY_DIR/api_key.json"
    else
        warn "No key entered. You can set it later:"
        warn "  echo '{\"key\":\"sk-or-...\"}' > $SHARED_KEY_DIR/api_key.json"
    fi
else
    ok "API key file already exists at $SHARED_KEY_DIR/api_key.json"
fi

# --- 9. Verify installation ---
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
info "Verifying installation..."
echo ""

# Check opencode binary
if command -v opencode &>/dev/null; then
    ok "opencode command is in PATH"
else
    warn "opencode not in PATH — add to ~/.bashrc:"
    warn '  export PATH="/usr/local/bin:$PATH"'
fi

# Check config
if [ -f "$OPENCODE_CONFIG_DIR/opencode.json" ]; then
    ok "Config file exists"
    python3 -c "import json; json.load(open('$OPENCODE_CONFIG_DIR/opencode.json')); print('     Config JSON is valid')"
fi

# Check wrapper
if [ -x "$WRAPPER_DST" ]; then
    ok "Wrapper is executable: $WRAPPER_DST"
fi

# Check API key
if [ -f "$SHARED_KEY_DIR/api_key.json" ]; then
    KEY=$(python3 -c "import json; print(json.load(open('$SHARED_KEY_DIR/api_key.json')).get('key','')[:12])" 2>/dev/null)
    if [ -n "$KEY" ] && [ "$KEY" != "YOUR_OPENRO" ]; then
        ok "API key configured: ${KEY}..."
    else
        warn "API key file exists but appears to be a placeholder"
        warn "Edit: $SHARED_KEY_DIR/api_key.json"
    fi
else
    warn "No API key file found"
fi

# --- 10. Done ---
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Installation Complete!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Next steps:"
echo "   1. Type:  opencode"
echo ""
echo "  OpenCode will connect to OpenRouter using your free API key."
echo "  The auto-routing endpoint 'openrouter/free' selects the best"
echo "  available free model for each request."
echo ""
echo "  Troubleshooting:"
echo "   - 'Missing Authentication header' → check API key file"
echo "   - 'Model not found' → run: opencode --version (must be >=1.0)"
echo "   - 'Permission denied' → run: chmod +x /usr/local/bin/opencode"
echo ""
