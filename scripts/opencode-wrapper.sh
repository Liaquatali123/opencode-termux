#!/usr/bin/env bash
# ============================================================
# opencode-wrapper.sh — OpenRouter API key loader for OpenCode
# ============================================================
# Installed at /usr/local/bin/opencode.
#
# On every launch:
#   1. Reads API key from Android shared storage (or local fallback)
#   2. Exports OPENROUTER_API_KEY
#   3. Injects key into provider options via OPENCODE_CONFIG_CONTENT
#      (the openrouter provider's env field doesn't pass the key to HTTP)
#   4. Execs the real OpenCode binary
#
# The API key lives on Android storage so it survives Termux
# reinstalls. Both Termux native apps and Ubuntu proot can
# access it at:
#   /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
# ============================================================

set -e

# Path to the real OpenCode binary (set by install.sh)
OPENCODE_REAL="/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe"

# API key on Android shared storage (persists across Termux reinstalls)
KEY_FILE="/storage/emulated/0/Download/ai_openrouter/configs/api_key.json"

# Fallback: local key file in case Android storage isn't mounted
LOCAL_KEY_FILE="$HOME/.config/opencode/api_key.json"

# --- Load API key ---
API_KEY=""
if [ -f "$KEY_FILE" ]; then
    API_KEY=$(python3 -c "
import json
print(json.load(open('$KEY_FILE')).get('key', ''))
" 2>/dev/null)
elif [ -f "$LOCAL_KEY_FILE" ]; then
    API_KEY=$(python3 -c "
import json
print(json.load(open('$LOCAL_KEY_FILE')).get('key', ''))
" 2>/dev/null)
fi

# --- Inject API key into provider options ---
# opencode's openrouter provider detects OPENROUTER_API_KEY in the
# environment but does NOT pass it as an HTTP auth header.
# The env field in config only lists the env var name, it doesn't
# actually read the value. Explicit apiKey via OPENCODE_CONFIG_CONTENT
# forces the provider to include the Authorization header.
if [ -n "$API_KEY" ]; then
    export OPENROUTER_API_KEY="$API_KEY"
    export OPENCODE_CONFIG_CONTENT='{"provider":{"openrouter":{"options":{"apiKey":"'"$API_KEY"'"}}}}'
fi

# --- Find real binary if path is wrong ---
if [ ! -f "$OPENCODE_REAL" ]; then
    OPENCODE_REAL=$(find /usr /usr/local -name "opencode.exe" -path "*opencode-ai*" 2>/dev/null | head -1)
fi

exec "$OPENCODE_REAL" "$@"
