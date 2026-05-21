#!/usr/bin/env bash
# ============================================================
# backup.sh — Backup all OpenCode + OpenRouter configs
# ============================================================
# Creates a timestamped backup of:
#   - ~/.config/opencode/ (config, AGENTS.md, plugin/)
#   - API key file
#   - Wrapper script at /usr/local/bin/opencode
#
# Usage:
#   bash backup.sh                    # default: backups/ folder
#   bash backup.sh /sdcard/backups   # custom destination
# ============================================================

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$REPO_DIR/backups}"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$DEST/opencode-backup-$TS"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }

echo -e "\n${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         OpenCode Config Backup              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}\n"

mkdir -p "$BACKUP_DIR"
info "Backing up to: $BACKUP_DIR"

# --- 1. OpenCode user config ---
if [ -d "$HOME/.config/opencode" ]; then
    cp -r "$HOME/.config/opencode" "$BACKUP_DIR/opencode-config"
    ok "Config dir backed up ($(du -sh "$BACKUP_DIR/opencode-config" | cut -f1))"
else
    warn "~/.config/opencode/ not found"
fi

# --- 2. API key ---
API_KEY_SRC="/storage/emulated/0/Download/ai_openrouter/configs/api_key.json"
if [ -f "$API_KEY_SRC" ]; then
    cp "$API_KEY_SRC" "$BACKUP_DIR/api_key.json"
    ok "API key backed up"
else
    warn "API key file not found at $API_KEY_SRC"
fi

# --- 3. Wrapper script ---
if [ -f "/usr/local/bin/opencode" ] && [ ! -L "/usr/local/bin/opencode" ]; then
    cp "/usr/local/bin/opencode" "$BACKUP_DIR/opencode-wrapper.sh"
    ok "Wrapper script backed up"
elif [ -f "/usr/local/bin/opencode" ]; then
    warn "Wrapper is a symlink — copying target"
    cp "$(readlink -f /usr/local/bin/opencode)" "$BACKUP_DIR/opencode-wrapper.sh" 2>/dev/null || true
fi

# --- 4. Node global packages ---
if command -v npm &>/dev/null; then
    npm list -g --depth=0 2>/dev/null > "$BACKUP_DIR/npm-global.txt"
    ok "npm global packages list saved"
fi

# --- 5. OpenCode binary info ---
if command -v opencode &>/dev/null; then
    opencode --version 2>/dev/null > "$BACKUP_DIR/opencode-version.txt" || true
    which opencode > "$BACKUP_DIR/opencode-path.txt" 2>/dev/null || true
    ok "OpenCode version recorded"
fi

# --- 6. Summary ---
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Backup complete: $BACKUP_DIR${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
ls -lh "$BACKUP_DIR/"
echo ""
info "To restore:  bash restore.sh $BACKUP_DIR"
echo ""
