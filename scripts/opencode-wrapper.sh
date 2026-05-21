#!/usr/bin/env bash
# ============================================================
# opencode-wrapper.sh — OpenRouter API key loader for OpenCode
# ============================================================
# Installed at /usr/local/bin/opencode.
# Reads API key from Android shared storage, injects it into
# OpenCode provider options via OPENCODE_CONFIG_CONTENT,
# then execs the real OpenCode binary.
#
# Why OPENCODE_CONFIG_CONTENT?
#   OpenCode's openrouter provider detects the OPENROUTER_API_KEY
#   env var but does NOT pass it as an HTTP auth header.
#   Explicit apiKey in provider options via OPENCODE_CONFIG_CONTENT
#   forces the provider to include Authorization: Bearer.
# ============================================================

# DO NOT use set -e — python3 may be missing on first run

# Path to real OpenCode binary (updated by install.sh)
OPENCODE_REAL="/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe"

# API key on Android shared storage (persists across Termux reinstalls)
KEY_FILE="/storage/emulated/0/Download/ai_openrouter/configs/api_key.json"

# Fallback: local key file
LOCAL_KEY_FILE="$HOME/.config/opencode/api_key.json"

# --- Load API key ---
API_KEY=""

if [ -f "$KEY_FILE" ] && command -v python3 &>/dev/null; then
    API_KEY=$(python3 -c "import json,sys; print(json.load(open('$KEY_FILE')).get('key',''))" 2>/dev/null)
fi

if [ -z "$API_KEY" ] && [ -f "$LOCAL_KEY_FILE" ] && command -v python3 &>/dev/null; then
    API_KEY=$(python3 -c "import json,sys; print(json.load(open('$LOCAL_KEY_FILE')).get('key',''))" 2>/dev/null)
fi

# Fallback: read env var directly
if [ -z "$API_KEY" ] && [ -n "$OPENROUTER_API_KEY" ]; then
    API_KEY="$OPENROUTER_API_KEY"
fi

# --- Inject into provider options ---
if [ -n "$API_KEY" ]; then
    export OPENROUTER_API_KEY="$API_KEY"
    # This is the critical fix: provider.options.apiKey sends the auth header
    export OPENCODE_CONFIG_CONTENT="{\"provider\":{\"openrouter\":{\"options\":{\"apiKey\":\"$API_KEY\"}}}}"
fi

# --- Find real binary if path is wrong ---
if [ ! -f "$OPENCODE_REAL" ]; then
    OPENCODE_REAL=$(find /usr /usr/local -name "opencode.exe" -path "*opencode-ai*" 2>/dev/null | head -1)
fi

exec "$OPENCODE_REAL" "$@"
