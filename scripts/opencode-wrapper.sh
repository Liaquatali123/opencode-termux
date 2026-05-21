#!/usr/bin/env bash
# ============================================================
# opencode-wrapper.sh — OpenRouter API key loader for OpenCode
# ============================================================
# This wrapper is installed at /usr/local/bin/opencode.
# On every launch it:
#   1. Reads the latest API key from the shared config
#   2. Exports OPENROUTER_API_KEY
#   3. Execs the real OpenCode binary
#
# The real binary lives at:
#   /usr/local/lib/node_modules/opencode-ai/bin/opencode.exe
#
# Why a wrapper instead of a config field?
#   OpenCode reads the API key at startup from the env var.
#   A wrapper guarantees the key is always present regardless
#   of shell profile, login state, or Termux restore.
# ============================================================

set -e

KEY_FILE="/storage/emulated/0/Download/ai_openrouter/configs/api_key.json"
OPENCODE_REAL="/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe"

# Always load the latest API key from the shared config file
if [ -f "$KEY_FILE" ]; then
    export OPENROUTER_API_KEY=$(python3 -c "
import json
d = json.load(open('$KEY_FILE'))
print(d.get('key', ''))
" 2>/dev/null)
fi

exec "$OPENCODE_REAL" "$@"
