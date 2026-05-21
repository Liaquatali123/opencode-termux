#!/usr/bin/env bash
# ============================================================
# restore.sh — Restore OpenCode + OpenRouter from backup
# ============================================================
# Usage:
#   bash restore.sh                     # auto-detect latest backup
#   bash restore.sh /path/to/backup     # specific backup dir
# ============================================================

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUPS_DIR="$REPO_DIR/backups"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERR]${NC}   $1"; }

echo -e "\n${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        OpenCode Config Restore              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}\n"

# --- Determine backup source ---
if [ -n "$1" ]; then
    BACKUP_DIR="$1"
else
    # Find the most recent backup
    BACKUP_DIR=$(ls -dt "$BACKUPS_DIR"/opencode-backup-* 2>/dev/null | head -1)
    if [ -z "$BACKUP_DIR" ]; then
        err "No backups found in $BACKUPS_DIR/"
        err "Usage: bash restore.sh /path/to/backup"
        exit 1
    fi
fi

if [ ! -d "$BACKUP_DIR" ]; then
    err "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

info "Restoring from: $BACKUP_DIR"

# --- 1. Restore OpenCode config ---
if [ -d "$BACKUP_DIR/opencode-config" ]; then
    if [ -d "$HOME/.config/opencode" ]; then
        mv "$HOME/.config/opencode" "$HOME/.config/opencode.bak.$(date +%s)"
        warn "Existing config moved to backup"
    fi
    mkdir -p "$HOME/.config"
    cp -r "$BACKUP_DIR/opencode-config" "$HOME/.config/opencode"
    ok "OpenCode config restored"
else
    warn "No opencode config in backup — skipping"
fi

# --- 2. Restore API key ---
if [ -f "$BACKUP_DIR/api_key.json" ]; then
    KEY_DIR="/storage/emulated/0/Download/ai_openrouter/configs"
    mkdir -p "$KEY_DIR"
    cp "$BACKUP_DIR/api_key.json" "$KEY_DIR/api_key.json"
    ok "API key restored to $KEY_DIR/api_key.json"
else
    warn "No API key in backup — you will need to set it manually"
fi

# --- 3. Restore wrapper ---
if [ -f "$BACKUP_DIR/opencode-wrapper.sh" ]; then
    cp "$BACKUP_DIR/opencode-wrapper.sh" "/usr/local/bin/opencode"
    chmod +x "/usr/local/bin/opencode"
    ok "Wrapper script restored"
else
    warn "No wrapper in backup — reinstall with: bash install.sh"
fi

# --- 4. Reinstall OpenCode if missing ---
if ! command -v opencode &>/dev/null; then
    info "OpenCode not found — reinstalling..."
    npm install -g opencode-ai
    ok "OpenCode reinstalled"
    # Refresh wrapper with correct binary path
    OPENCODE_REAL=$(find /usr -name "opencode.exe" -path "*/opencode-ai/*" 2>/dev/null | head -1)
    if [ -n "$OPENCODE_REAL" ] && [ -f "/usr/local/bin/opencode" ]; then
        sed -i "s|OPENCODE_REAL=.*|OPENCODE_REAL=\"$OPENCODE_REAL\"|" "/usr/local/bin/opencode"
        ok "Wrapper binary path updated"
    fi
fi

# --- 5. Verify ---
echo ""
info "Verifying restore..."
errors=0
[ -f "$HOME/.config/opencode/opencode.json" ] && ok "Config present" || { warn "Config missing"; ((errors++)); }
[ -f "/usr/local/bin/opencode" ] && ok "Wrapper present" || { err "Wrapper missing"; ((errors++)); }
command -v node &>/dev/null && ok "Node.js $(node -v)" || { err "Node.js missing"; ((errors++)); }
command -v opencode &>/dev/null && ok "OpenCode $(opencode --version)" || { err "OpenCode missing"; ((errors++)); }

echo ""
if [ "$errors" -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Restore Complete!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Run:  opencode"
else
    echo -e "${YELLOW}Restore completed with $errors warning(s).${NC}"
    echo "  Run: bash install.sh  to fix missing components"
fi
echo ""
