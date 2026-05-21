#!/usr/bin/env bash
# ============================================================
# backup.sh — Backup OpenCode + OpenRouter configs
# ============================================================
# Saves everything needed to restore after a factory reset:
#   - ~/.config/opencode/ (opencode.json, AGENTS.md, plugins)
#   - API key from Android shared storage
#   - Wrapper script at /usr/local/bin/opencode
#   - npm global package list
#   - OpenCode version info
#   - Ubuntu proot-distro config (if available)
#
# Usage:
#   bash backup.sh                        # → backups/opencode-backup-<ts>/
#   bash backup.sh /sdcard/backups        # custom location
#   bash backup.sh /storage/emulated/0/   # save to Android storage
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

# --- 2. API key (try Android storage first, then local) ---
API_KEY_FOUND=false
for api_src in \
    "/storage/emulated/0/Download/ai_openrouter/configs/api_key.json" \
    "$HOME/.config/opencode/api_key.json"; do
    if [ -f "$api_src" ]; then
        cp "$api_src" "$BACKUP_DIR/api_key.json"
        ok "API key backed up from $api_src"
        API_KEY_FOUND=true
        break
    fi
done
if [ "$API_KEY_FOUND" = false ]; then
    warn "No API key file found"
fi

# --- 3. Wrapper script ---
if [ -f "/usr/local/bin/opencode" ]; then
    cp "/usr/local/bin/opencode" "$BACKUP_DIR/opencode-wrapper.sh"
    ok "Wrapper script backed up"
else
    warn "Wrapper script not found at /usr/local/bin/opencode"
fi

# --- 4. Ubuntu proot container metadata ---
PROOT_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro"
if [ -d "$PROOT_DIR" ]; then
    # Save proot-distro list and Ubuntu release info
    proot-distro list 2>/dev/null > "$BACKUP_DIR/proot-distro-list.txt" || true
    if [ -f "$PROOT_DIR/containers/ubuntu/etc/os-release" ]; then
        cp "$PROOT_DIR/containers/ubuntu/etc/os-release" "$BACKUP_DIR/ubuntu-os-release.txt"
        ok "Ubuntu proot metadata saved"
    fi
fi

# --- 5. Node global packages ---
if command -v npm &>/dev/null; then
    npm list -g --depth=0 2>/dev/null > "$BACKUP_DIR/npm-global.txt"
    ok "npm global packages list saved"
fi

# --- 6. OpenCode binary info ---
if command -v opencode &>/dev/null; then
    opencode --version 2>/dev/null > "$BACKUP_DIR/opencode-version.txt" || true
    which opencode > "$BACKUP_DIR/opencode-path.txt" 2>/dev/null || true
    ok "OpenCode version recorded"
fi

# --- 7. Architecture info ---
uname -a > "$BACKUP_DIR/system-info.txt" 2>/dev/null || true
if [ -f /etc/os-release ]; then
    cp /etc/os-release "$BACKUP_DIR/os-release.txt"
fi
ok "System info saved"

# --- 8. Summary ---
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Backup complete: $BACKUP_DIR${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
ls -lh "$BACKUP_DIR/"
echo ""
info "To restore on a fresh Termux:"
info "  1. Install git + clone this repo"
info "  2. bash restore.sh $BACKUP_DIR"
echo ""
