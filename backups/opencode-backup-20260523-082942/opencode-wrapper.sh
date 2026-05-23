#!/usr/bin/env bash
OPENCODE_REAL="/root/.opencode/bin/opencode"
KEY_FILE="/root/.config/opencode/api_key.json"
API_KEY=""
if [ -f "$KEY_FILE" ] && command -v python3 &>/dev/null; then
    API_KEY=$(python3 -c "import json,sys; print(json.load(open('$KEY_FILE')).get('key',''))" 2>/dev/null)
fi
if [ -z "$API_KEY" ] && [ -n "$OPENROUTER_API_KEY" ]; then
    API_KEY="$OPENROUTER_API_KEY"
fi
if [ -n "$API_KEY" ]; then
    export OPENROUTER_API_KEY="$API_KEY"
    export OPENCODE_CONFIG_CONTENT="{\"provider\":{\"openrouter\":{\"options\":{\"apiKey\":\"$API_KEY\"}}}}"
fi
exec "$OPENCODE_REAL" "$@"
