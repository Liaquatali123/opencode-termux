#!/usr/bin/env bash
# ============================================================
# opencode-wrapper.sh — OpenRouter API key loader for OpenCode
# ============================================================
# Installed at /usr/local/bin/opencode.
#
# On every launch:
#   1. Reads the latest API key from Android shared storage
#   2. Exports OPENROUTER_API_KEY
#   3. Execs the real OpenCode binary
#
# The API key lives on Android storage so it survives Termux
# reinstalls. Both Termux native apps and Ubuntu proot can
# access it at:
#   /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
#
# Why a wrapper instead of a config field?
#   OpenCode reads the API key at startup from the env var.
#   A wrapper guarantees the key is always present regardless
#   of shell profile, login state, or Termux reinstall.
# ============================================================

set -e

# Path to the real OpenCode binary (set by install.sh)
OPENCODE_REAL="/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe"

# API key on Android shared storage (persists across Termux reinstalls)
KEY_FILE="/storage/emulated/0/Download/ai_openrouter/configs/api_key.json"

# Fallback: local key file in case Android storage isn't mounted
LOCAL_KEY_FILE="$HOME/.config/opencode/api_key.json"

# --- Load API key ---
if [ -f "$KEY_FILE" ]; then
    export OPENROUTER_API_KEY=$(python3 -c "
import json
d = json.load(open('$KEY_FILE'))
print(d.get('key', ''))
" 2>/dev/null)
elif [ -f "$LOCAL_KEY_FILE" ]; then
    export OPENROUTER_API_KEY=$(python3 -c "
import json
d = json.load(open('$LOCAL_KEY_FILE'))
print(d.get('key', ''))
" 2>/dev/null)
fi

# If the real binary doesn't exist at the compiled-in path, search for it
if [ ! -f "$OPENCODE_REAL" ]; then
    OPENCODE_REAL=$(find /usr /usr/local -name "opencode.exe" -path "*/opencode-ai/*" 2>/dev/null | head -1)
fi

exec "$OPENCODE_REAL" "$@"
