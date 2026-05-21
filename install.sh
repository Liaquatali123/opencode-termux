#!/usr/bin/env bash
# ============================================================
# install.sh — OpenCode + OpenRouter setup for Termux → Ubuntu
# ============================================================
# Architecture:
#   Android → Termux → proot-distro → Ubuntu → OpenCode
#
# Usage (fresh Termux):
#   pkg install git -y
#   git clone https://github.com/Liaquatali123/opencode-termux.git
#   cd opencode-termux
#   bash install.sh
#   opencode
#
# What it does:
#   1. Detects Termux vs Ubuntu environment
#   2. Termux: installs proot-distro + Ubuntu, copies repo in, runs inside
#   3. Ubuntu: installs Node.js 22 + npm via apt
#   4. Installs OpenCode globally via npm
#   5. Creates ~/.config/opencode/ with opencode.json + AGENTS.md
#   6. Installs wrapper at /usr/local/bin/opencode (loads API key, injects auth)
#   7. Auto-detects existing API key on Android storage (no re-prompt)
#   8. Creates Termux launcher so 'opencode' works from Termux shell
#   9. Verifies everything end-to-end
# ============================================================

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()   { echo -e "${RED}[ERR]${NC}   $1"; }

# Shared paths
SHARED_KEY_DIR="/storage/emulated/0/Download/ai_openrouter/configs"
LOCAL_KEY_DIR="$HOME/.config/opencode"

# ============================================================
echo -e "\n${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   OpenCode + OpenRouter  |  Termux → Ubuntu  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}\n"

# ============================================================
# ENVIRONMENT DETECTION
# ============================================================
IS_TERMUX=false
IS_UBUNTU=false
INSIDE_UBUNTU=false

[ "$1" = "--inside-ubuntu" ] && INSIDE_UBUNTU=true

# Check Ubuntu FIRST — Termux files are bind-mounted inside proot
if [ -f "/etc/os-release" ] && grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    IS_UBUNTU=true
    info "Detected: Ubuntu $(grep VERSION_ID /etc/os-release | cut -d'\"' -f2)"
elif [ -f "/data/data/com.termux/files/usr/bin/pkg" ] && \
     [ -d "/data/data/com.termux" ]; then
    IS_TERMUX=true
    info "Detected: Termux (native Android)"
elif [ "$INSIDE_UBUNTU" = true ]; then
    info "Running with --inside-ubuntu flag"
else
    warn "Unknown environment — continuing with generic Linux setup"
fi

# ============================================================
# TERMUX MODE: Install proot + Ubuntu, then re-run inside
# ============================================================
if [ "$IS_TERMUX" = true ] && [ "$INSIDE_UBUNTU" = false ]; then
    info "Setting up Ubuntu proot container..."

    # Install proot-distro
    if ! command -v proot-distro &>/dev/null; then
        info "Installing proot-distro..."
        pkg update -y
        pkg install proot-distro -y
        ok "proot-distro installed"
    else
        ok "proot-distro already installed"
    fi

    # Install Ubuntu if missing
    UBUNTU_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu"
    if [ ! -d "$UBUNTU_ROOT" ] || [ ! -f "$UBUNTU_ROOT/etc/os-release" ]; then
        info "Installing Ubuntu 26.04 LTS (may take a few minutes)..."
        proot-distro install ubuntu
        ok "Ubuntu installed"
    else
        ok "Ubuntu already installed ($(grep VERSION_ID "$UBUNTU_ROOT/etc/os-release" 2>/dev/null | cut -d'\"' -f2))"
    fi

    # Copy repo into Ubuntu container (excluding .git)
    UBUNTU_REPO="$UBUNTU_ROOT/root/opencode-termux"
    info "Copying repo into Ubuntu container..."
    rm -rf "$UBUNTU_REPO"
    mkdir -p "$UBUNTU_REPO"
    for item in "$REPO_DIR"/*; do
        [ -e "$item" ] && cp -r "$item" "$UBUNTU_REPO/"
    done
    ok "Repo copied to $UBUNTU_REPO"

    # Run installer inside Ubuntu
    echo ""
    info "Continuing installation inside Ubuntu proot..."
    proot-distro login ubuntu -- bash -c "
        export HOME=/root
        cd /root/opencode-termux
        bash install.sh --inside-ubuntu
    "

    # Create Termux launcher so 'opencode' works from Termux
    TERMUX_LAUNCHER="/data/data/com.termux/files/usr/bin/opencode"
    if [ ! -f "$TERMUX_LAUNCHER" ]; then
        info "Creating Termux launcher: $TERMUX_LAUNCHER"
        cat > "$TERMUX_LAUNCHER" << 'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login ubuntu -- bash -c "export HOME=/root && cd ~ && exec /usr/local/bin/opencode \"$@\""
LAUNCHER
        chmod +x "$TERMUX_LAUNCHER"
        ok "Termux launcher created. Now type: opencode"
    else
        ok "Termux launcher already exists"
    fi

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Termux → Ubuntu Setup Complete!        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Next step:"
    echo "    opencode"
    echo ""
    exit 0
fi

# ============================================================
# UBUNTU / LINUX MODE: Install Node.js, OpenCode, configs
# ============================================================

# --- 1. Update apt cache ---
info "Updating apt package cache..."
apt update -qq 2>/dev/null || true

# --- 2. Install Node.js + npm ---
info "Checking Node.js..."
if command -v node &>/dev/null; then
    ok "Node.js $(node -v)"
else
    info "Installing Node.js + npm via apt..."
    apt install -y -qq nodejs npm 2>/dev/null || {
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt install -y nodejs
    }
    ok "Node.js $(node -v) installed"
fi

# --- 3. Install OpenCode ---
info "Checking OpenCode..."
if OPENCODE_VER=$(opencode --version 2>/dev/null); then
    ok "OpenCode $OPENCODE_VER"
else
    info "Installing OpenCode via npm..."
    npm install -g opencode-ai
    ok "OpenCode $(opencode --version) installed"
fi

# --- 4. Find real opencode binary ---
OPENCODE_REAL=""
for candidate in \
    "/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe" \
    "/usr/lib/node_modules/opencode-ai/bin/opencode.exe" \
    "$(npm root -g 2>/dev/null)/opencode-ai/bin/opencode.exe"; do
    if [ -f "$candidate" ]; then
        OPENCODE_REAL="$candidate"
        break
    fi
done
if [ -z "$OPENCODE_REAL" ]; then
    OPENCODE_REAL=$(find /usr /usr/local -name "opencode.exe" -path "*/opencode-ai/*" 2>/dev/null | head -1)
fi
if [ -z "$OPENCODE_REAL" ]; then
    err "Cannot find opencode binary! npm install may have failed."
    err "Check: npm root -g"
    exit 1
fi
ok "Real binary: $OPENCODE_REAL"

# --- 5. Create config directory ---
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

# --- 6. Copy opencode.json ---
if [ -f "$REPO_DIR/configs/opencode.json" ]; then
    cp "$REPO_DIR/configs/opencode.json" "$OPENCODE_CONFIG_DIR/opencode.json"
    ok "Config: $OPENCODE_CONFIG_DIR/opencode.json"
else
    err "configs/opencode.json not found in repo!"
    exit 1
fi

# --- 7. Copy AGENTS.md ---
if [ -f "$REPO_DIR/AGENTS.md" ]; then
    cp "$REPO_DIR/AGENTS.md" "$OPENCODE_CONFIG_DIR/AGENTS.md"
    ok "AGENTS.md copied"
fi

# --- 8. Install wrapper ---
info "Installing wrapper at /usr/local/bin/opencode..."
WRAPPER_SRC="$REPO_DIR/scripts/opencode-wrapper.sh"
WRAPPER_DST="/usr/local/bin/opencode"

# Fill in the correct paths in the wrapper template
sed -e "s|^OPENCODE_REAL=.*|OPENCODE_REAL=\"$OPENCODE_REAL\"|" \
    "$WRAPPER_SRC" > /tmp/opcode-wrapper-install

cp /tmp/opcode-wrapper-install "$WRAPPER_DST"
chmod +x "$WRAPPER_DST"
rm -f /tmp/opcode-wrapper-install
ok "Wrapper: $WRAPPER_DST"

# --- 9. API key ---
mkdir -p "$SHARED_KEY_DIR" 2>/dev/null || true
mkdir -p "$LOCAL_KEY_DIR" 2>/dev/null || true

# Check for existing key on Android storage
API_KEY=""
if [ -f "$SHARED_KEY_DIR/api_key.json" ]; then
    API_KEY=$(python3 -c "import json;print(json.load(open('$SHARED_KEY_DIR/api_key.json')).get('key',''))" 2>/dev/null || echo "")
fi

# Fallback: check local
if [ -z "$API_KEY" ] && [ -f "$LOCAL_KEY_DIR/api_key.json" ]; then
    API_KEY=$(python3 -c "import json;print(json.load(open('$LOCAL_KEY_DIR/api_key.json')).get('key',''))" 2>/dev/null || echo "")
fi

if [ -n "$API_KEY" ] && [ "$API_KEY" != "YOUR_OPENROUTER_API_KEY_HERE" ]; then
    ok "API key loaded: ${API_KEY:0:12}..."
    # Ensure it's on Android storage (for persistence)
    if [ -d "/storage/emulated/0" ]; then
        echo "{\"key\": \"$API_KEY\", \"saved\": \"$(date -Iseconds)\"}" > "$SHARED_KEY_DIR/api_key.json"
    fi
else
    # Prompt for key
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  OpenRouter API Key Setup${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  Get a free key: https://openrouter.ai/keys"
    echo ""
    read -r -p "  Paste your OpenRouter API key (sk-or-...): " USER_KEY
    if [ -n "$USER_KEY" ]; then
        API_KEY="$USER_KEY"
        if [ -d "/storage/emulated/0" ]; then
            echo "{\"key\": \"$API_KEY\", \"saved\": \"$(date -Iseconds)\"}" > "$SHARED_KEY_DIR/api_key.json"
            ok "API key saved to Android storage: $SHARED_KEY_DIR/api_key.json"
        else
            echo "{\"key\": \"$API_KEY\", \"saved\": \"$(date -Iseconds)\"}" > "$LOCAL_KEY_DIR/api_key.json"
            ok "API key saved to $LOCAL_KEY_DIR/api_key.json"
        fi
    else
        warn "No key entered. Set it later with:"
        warn "  echo '{\"key\":\"sk-or-...\"}' > $SHARED_KEY_DIR/api_key.json"
    fi
fi

# Save API key to where the wrapper can find it
if [ -n "$API_KEY" ] && [ "$API_KEY" != "YOUR_OPENROUTER_API_KEY_HERE" ]; then
    export OPENROUTER_API_KEY="$API_KEY"
fi

# --- 10. Verify ---
echo ""
info "Verifying installation..."
errors=0
command -v opencode &>/dev/null && ok "✓ opencode in PATH" || { err "opencode not in PATH"; ((errors++)); }
[ -f "$OPENCODE_CONFIG_DIR/opencode.json" ] && ok "✓ Config: opencode.json" || { warn "Config missing"; ((errors++)); }
[ -x "$WRAPPER_DST" ] && ok "✓ Wrapper: $WRAPPER_DST" || { warn "Wrapper missing"; ((errors++)); }
command -v node &>/dev/null && ok "✓ Node.js $(node -v)" || { err "Node.js missing"; ((errors++)); }
command -v npm &>/dev/null && ok "✓ npm $(npm -v)" || true

if [ -n "$API_KEY" ] && [ "$API_KEY" != "YOUR_OPENROUTER_API_KEY_HERE" ]; then
    ok "✓ API key configured: ${API_KEY:0:12}..."
else
    warn "API key not configured"
    ((errors++))
fi

# Test auth with actual API call
if [ -n "$API_KEY" ] && [ "$API_KEY" != "YOUR_OPENROUTER_API_KEY_HERE" ]; then
    echo ""
    info "Testing OpenRouter API connection..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model":"openrouter/free","messages":[{"role":"user","content":"ping"}],"max_tokens":5}' 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        ok "✓ OpenRouter API: connected (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "429" ]; then
        ok "✓ OpenRouter API: connected (HTTP $HTTP_CODE — rate limited, auth OK)"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        err "OpenRouter API: auth failed (HTTP $HTTP_CODE)"
        ((errors++))
    else
        warn "OpenRouter API: HTTP $HTTP_CODE (may be network issue)"
    fi
fi

# --- 11. Done ---
echo ""
if [ "$errors" -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Installation Complete!               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Terminal: $IS_TERMUX"
    echo "  Ubuntu:   $IS_UBUNTU"
    echo "  Node:     $(node -v)"
    echo "  OpenCode: $(opencode --version)"
    echo ""
    echo "  Next step:"
    echo "    opencode"
    echo ""
    echo "  Backup:   bash backup.sh"
    echo "  Restore:  bash restore.sh"
else
    echo -e "${YELLOW}Installation completed with $errors warning(s).${NC}"
    echo "  Check the warnings above before running opencode."
fi
echo ""
