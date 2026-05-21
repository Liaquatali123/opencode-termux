#!/usr/bin/env bash
# ============================================================
# install.sh — OpenCode + OpenRouter setup for Termux → Ubuntu
# ============================================================
# Architecture:
#   Android → Termux → proot-distro → Ubuntu 26.04 → OpenCode
#
# Why Ubuntu/proot?
#   OpenCode's Node.js runtime has better compatibility on
#   Ubuntu aarch64 than on native Termux ARM64. The proot
#   container provides a full Linux environment with apt,
#   proper file paths, and fewer ARM64 compatibility issues.
#
# Usage:
#   pkg install git -y
#   git clone https://github.com/Liaquatali123/opencode-termux.git
#   cd opencode-termux
#   bash install.sh
#
# What it does:
#   ▸ Detects Termux vs Ubuntu environment
#   ▸ Termux mode: installs proot-distro, sets up Ubuntu, copies
#     repo into Ubuntu, runs install.sh inside Ubuntu
#   ▸ Ubuntu mode: installs Node.js, OpenCode, config, wrapper,
#     API key setup, verification
#   ▸ Shared API key on Android storage for persistence across
#     Termux reinstalls
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
echo -e "${CYAN}║   OpenCode + OpenRouter  |  Termux → Ubuntu  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}\n"

# ============================================================
# ENVIRONMENT DETECTION
# ============================================================
IS_TERMUX=false
IS_UBUNTU=false

if [ -f "/data/data/com.termux/files/usr/bin/pkg" ] && \
   [ -d "/data/data/com.termux" ]; then
    IS_TERMUX=true
    info "Detected: Termux (native Android environment)"
elif [ -f "/etc/os-release" ] && grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    IS_UBUNTU=true
    info "Detected: Ubuntu $(grep VERSION_ID /etc/os-release 2>/dev/null | cut -d'"' -f2)"
else
    warn "Unknown environment — continuing with generic Linux setup"
fi

# ============================================================
# TERMUX MODE: Install proot-distro + Ubuntu, then re-run inside
# ============================================================
if [ "$IS_TERMUX" = true ]; then
    info "Termux detected — setting up Ubuntu proot container..."

    # --- Install proot-distro if missing ---
    if ! command -v proot-distro &>/dev/null; then
        info "Installing proot-distro..."
        pkg update -y
        pkg install proot-distro -y
        ok "proot-distro installed"
    else
        ok "proot-distro already installed"
    fi

    # --- Install or update Ubuntu ---
    UBUNTU_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu"
    UBUNTU_LOGIN="proot-distro login ubuntu"

    if [ ! -d "$UBUNTU_ROOT" ] || [ ! -f "$UBUNTU_ROOT/etc/os-release" ]; then
        info "Installing Ubuntu 26.04 LTS (this may take a few minutes)..."
        proot-distro install ubuntu
        ok "Ubuntu installed"
    else
        ok "Ubuntu already installed ($(grep VERSION_ID "$UBUNTU_ROOT/etc/os-release" 2>/dev/null | cut -d'"' -f2))"
    fi

    # --- Copy repo into Ubuntu container ---
    UBUNTU_REPO="$UBUNTU_ROOT/root/opencode-termux"
    info "Copying repo into Ubuntu container at $UBUNTU_REPO..."
    rm -rf "$UBUNTU_REPO"
    mkdir -p "$UBUNTU_REPO"
    cp -r "$REPO_DIR"/* "$UBUNTU_REPO/"
    ok "Repo copied to Ubuntu container"

    # --- Ensure shared Android storage is accessible inside proot ---
    # proot-distro typically mounts /storage automatically, but verify
    if [ ! -d "$UBUNTU_ROOT/storage/emulated/0" ]; then
        warn "Android storage may not be mounted inside proot automatically."
        warn "OpenCode wrapper needs access to:"
        warn "  /storage/emulated/0/Download/ai_openrouter/configs/api_key.json"
        warn ""
        warn "If missing, restart Termux and re-run install.sh"
    fi

    # --- Run installer inside Ubuntu ---
    echo ""
    info "Switching to Ubuntu proot environment..."
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  The installer will continue inside Ubuntu.${NC}"
    echo -e "${YELLOW}  You may be prompted for API key.${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Run install.sh inside Ubuntu (the --inside-ubuntu flag skips this check)
    proot-distro login ubuntu -- bash -c "
        cd /root/opencode-termux && bash install.sh --inside-ubuntu
    "

    # --- Create launcher in Termux that enters proot and runs opencode ---
    TERMUX_LAUNCHER="/data/data/com.termux/files/usr/bin/opencode"
    if [ ! -f "$TERMUX_LAUNCHER" ]; then
        info "Creating Termux launcher script: $TERMUX_LAUNCHER"
        cat > "$TERMUX_LAUNCHER" << 'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
# OpenCode launcher for Termux — enters Ubuntu proot and runs opencode
exec proot-distro login ubuntu -- bash -c "export HOME=/root && cd ~ && exec opencode \"$@\""
LAUNCHER
        chmod +x "$TERMUX_LAUNCHER"
        ok "Termux launcher created: termux-open  (or just: opencode)"
        warn "Note: 'opencode' command currently points to proot launcher."
        warn "If it conflicts with another binary, use: termux-open"
    else
        ok "Termux launcher already exists"
    fi

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Termux → Ubuntu Setup Complete!        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Run OpenCode from Termux:"
    echo "    opencode"
    echo ""
    echo "  Or enter Ubuntu manually:"
    echo "    proot-distro login ubuntu"
    echo "    opencode"
    echo ""
    exit 0
fi

# ============================================================
# UBUNTU / GENERIC LINUX MODE: Actual installation
# ============================================================
# If we reach here, we're inside Ubuntu (or another Linux distro)

# --- Skip the "inside Ubuntu" guard if --inside-ubuntu flag is passed ---
INSIDE_UBUNTU=false
if [ "$1" = "--inside-ubuntu" ]; then
    INSIDE_UBUNTU=true
fi

if [ "$IS_UBUNTU" = false ] && [ "$INSIDE_UBUNTU" = false ]; then
    warn "Not running inside Ubuntu."
    warn "If you are running this from inside a proot container,"
    warn "use: bash install.sh --inside-ubuntu"
fi

# --- 1. Install Node.js + npm ---
info "Checking Node.js..."
if command -v node &>/dev/null; then
    ok "Node.js $(node -v) already installed"
else
    info "Installing Node.js via apt..."
    apt update -qq && apt install -y -qq nodejs npm 2>/dev/null || {
        # Fallback: nodesource
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt install -y nodejs
    }
    ok "Node.js $(node -v) installed"
fi

# --- 2. Install OpenCode ---
info "Checking OpenCode..."
if command -v opencode &>/dev/null && [ -x "$(command -v opencode)" ]; then
    ok "OpenCode $(opencode --version 2>/dev/null) already installed"
else
    info "Installing OpenCode globally via npm..."
    npm install -g opencode-ai
    ok "OpenCode $(opencode --version 2>/dev/null) installed"
fi

# --- 3. Create config directory ---
info "Setting up config directory..."
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

# --- 4. Copy opencode.json ---
if [ -f "$REPO_DIR/configs/opencode.json" ]; then
    cp "$REPO_DIR/configs/opencode.json" "$OPENCODE_CONFIG_DIR/opencode.json"
    ok "Config copied: $OPENCODE_CONFIG_DIR/opencode.json"
else
    err "configs/opencode.json not found in repo!"
    exit 1
fi

# --- 5. Copy AGENTS.md ---
if [ -f "$REPO_DIR/AGENTS.md" ]; then
    cp "$REPO_DIR/AGENTS.md" "$OPENCODE_CONFIG_DIR/AGENTS.md"
    ok "AGENTS.md copied"
fi

# --- 6. Install wrapper ---
info "Installing opencode wrapper..."
WRAPPER_SRC="$REPO_DIR/scripts/opencode-wrapper.sh"
WRAPPER_DST="/usr/local/bin/opencode"

# Find the real opencode binary (npm global install location varies)
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

ok "Real binary found at: $OPENCODE_REAL"

# Generate wrapper with correct paths
sed -e "s|OPENCODE_REAL=.*|OPENCODE_REAL=\"$OPENCODE_REAL\"|" \
    -e "s|KEY_FILE=.*|KEY_FILE=\"$SHARED_KEY_DIR/api_key.json\"|" \
    "$WRAPPER_SRC" > /tmp/opcode-wrapper-install

cp /tmp/opcode-wrapper-install "$WRAPPER_DST"
chmod +x "$WRAPPER_DST"
rm -f /tmp/opcode-wrapper-install
ok "Wrapper installed: $WRAPPER_DST"

# --- 7. Create launcher in /usr/local/bin if not exists ---
if [ ! -f "/usr/local/bin/opencode" ]; then
    # Shouldn't happen since we just installed it above, but just in case
    warn "Wrapper not found at /usr/local/bin/opencode"
    cp "$WRAPPER_SRC" "/usr/local/bin/opencode"
    chmod +x "/usr/local/bin/opencode"
    ok "Wrapper created at /usr/local/bin/opencode"
fi

# --- 8. API key setup ---
# The API key is stored on Android storage so it persists across
# Termux reinstalls. It's accessible from inside the proot at:
#   /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
SHARED_KEY_DIR="/storage/emulated/0/Download/ai_openrouter/configs"

if [ -d "/storage/emulated/0" ]; then
    # Android storage is accessible (we're inside proot with bind mount)
    mkdir -p "$SHARED_KEY_DIR"

    if [ ! -f "$SHARED_KEY_DIR/api_key.json" ]; then
        info "No API key found on Android shared storage."
        echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  OpenRouter API Key Setup${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  Get a free API key at: https://openrouter.ai/keys"
        echo ""
        read -r -p "  Paste your OpenRouter API key (sk-or-...): " USER_KEY
        if [ -n "$USER_KEY" ]; then
            echo "{\"key\": \"$USER_KEY\", \"saved\": \"$(date -Iseconds)\"}" > "$SHARED_KEY_DIR/api_key.json"
            ok "API key saved to Android storage: $SHARED_KEY_DIR/api_key.json"
        else
            warn "No key entered. You can set it later:"
            warn "  echo '{\"key\":\"sk-or-...\"}' > $SHARED_KEY_DIR/api_key.json"
        fi
    else
        ok "API key file already exists on Android storage"
    fi
else
    # Android storage not mounted (running on bare Linux, not Termux/proot)
    warn "Android storage not accessible — saving API key locally."
    LOCAL_KEY_DIR="$HOME/.config/opencode"
    if [ ! -f "$LOCAL_KEY_DIR/api_key.json" ]; then
        info "No API key found."
        echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  OpenRouter API Key Setup${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        read -r -p "  Paste your OpenRouter API key (sk-or-...): " USER_KEY
        if [ -n "$USER_KEY" ]; then
            echo "{\"key\": \"$USER_KEY\", \"saved\": \"$(date -Iseconds)\"}" > "$LOCAL_KEY_DIR/api_key.json"
            ok "API key saved to $LOCAL_KEY_DIR/api_key.json"
        fi
    fi
fi

# --- 9. Verify installation ---
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
info "Verifying installation..."
echo ""

errors=0
command -v opencode &>/dev/null && ok "opencode in PATH" || { warn "opencode not in PATH"; ((errors++)); }
[ -f "$OPENCODE_CONFIG_DIR/opencode.json" ] && ok "Config present" || { warn "Config missing"; ((errors++)); }
[ -x "/usr/local/bin/opencode" ] && ok "Wrapper executable" || { warn "Wrapper missing"; ((errors++)); }
command -v node &>/dev/null && ok "Node.js $(node -v)" || { err "Node.js missing"; ((errors++)); }

if [ -f "$SHARED_KEY_DIR/api_key.json" ] || [ -f "$HOME/.config/opencode/api_key.json" ]; then
    KEY_FILE="${SHARED_KEY_DIR}/api_key.json"
    [ ! -f "$KEY_FILE" ] && KEY_FILE="$HOME/.config/opencode/api_key.json"
    KEY=$(python3 -c "import json; print(json.load(open('$KEY_FILE')).get('key','')[:12])" 2>/dev/null)
    if [ -n "$KEY" ] && [ "$KEY" != "YOUR_OPENRO" ]; then
        ok "API key configured: ${KEY}..."
    else
        warn "API key appears to be a placeholder"
    fi
else
    warn "No API key file found — set it before running opencode"
    ((errors++))
fi

# --- 10. Done ---
echo ""
if [ "$errors" -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Installation Complete!               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Architecture:  Android → Termux → proot-distro → Ubuntu → OpenCode"
    echo ""
    echo "  Next step:"
    echo "    opencode"
    echo ""
    echo "  OpenCode connects to OpenRouter using your free API key."
    echo "  Model auto-routing selects the best available free model."
    echo ""
    echo "  Backup:  bash backup.sh"
    echo "  Restore: bash restore.sh"
else
    echo -e "${YELLOW}Installation completed with $errors warning(s).${NC}"
    echo "  Check the warnings above and fix before running opencode."
fi
echo ""
