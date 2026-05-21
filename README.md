# OpenCode + OpenRouter — Termux Setup

One-command installer for **OpenCode** (AI coding assistant) connected to
**OpenRouter** (free model API gateway) on Android Termux.

```
opencode
→ loads API key from shared config
→ connects to OpenRouter auto-routing endpoint
→ restores last session automatically
→ ready instantly — no manual setup
```

---

## Quick Install (Fresh Termux)

```bash
# 1. Update packages
pkg update -y && pkg upgrade -y

# 2. Install git (may already be installed)
pkg install git -y

# 3. Clone this repo
git clone https://github.com/Liaquatali123/opencode-termux.git
cd opencode-termux

# 4. Run installer
bash install.sh

# 5. Start coding
opencode
```

The installer will:
- Install Node.js and npm
- Install OpenCode globally
- Copy config files to `~/.config/opencode/`
- Install the wrapper script at `/usr/local/bin/opencode`
- Prompt for your OpenRouter API key (or reuse existing)
- Verify everything works

---

## What Gets Installed

```
/usr/local/bin/opencode          → Wrapper script (loads API key, execs real binary)
/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe  → Real OpenCode binary
~/.config/opencode/opencode.json → OpenCode configuration (provider, model, permissions)
~/.config/opencode/AGENTS.md     → Model priority list & fallback rules
/storage/emulated/0/Download/ai_openrouter/configs/api_key.json → Shared API key
```

---

## Repository Structure

```
opencode-termux/
├── install.sh                  # One-command fresh install
├── backup.sh                   # Backup all configs + API key
├── restore.sh                  # Restore from backup
├── configs/
│   ├── opencode.json           # OpenCode configuration template
│   └── api_key.json            # API key placeholder
├── scripts/
│   └── opencode-wrapper.sh     # Wrapper script source
├── AGENTS.md                   # Model priority & fallback rules
├── backups/                    # Created by backup.sh
└── README.md                   # This file
```

---

## How OpenCode + OpenRouter Work Together

### Startup Flow

```
User types: opencode
    │
    ▼
/usr/local/bin/opencode  (wrapper script)
    │  Reads: /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
    │  Exports: OPENROUTER_API_KEY
    ▼
opencode.exe  (real binary)
    │  Loads: ~/.config/opencode/opencode.json
    │  Reads: model = "openrouter/openrouter/free"
    │  Reads: provider.openrouter.env = ["OPENROUTER_API_KEY"]
    │  Reads: instructions = ["AGENTS.md"]
    ▼
OpenRouter API  (https://openrouter.ai/api/v1/chat/completions)
    │  Auth: Authorization: Bearer sk-or-...
    │  Auto-routes to best available free model
    ▼
Ready for coding
```

### Per-Request Flow

```
You type a message
    → OpenCode builds chat payload with conversation history
    → POST to OpenRouter with streaming enabled
    → OpenRouter auto-routes to available free model:
        Primary:   openrouter/free                  (auto-routing)
        Fallback:  qwen/qwen3-coder:free            (code)
        Fallback:  deepseek/deepseek-chat:free      (general)
        Fallback:  meta-llama/llama-3.3-70b:free    (large context)
    → Streamed response parsed by OpenCode
    → Tool calls (read, write, bash, grep, glob) executed
    → Results fed back to AI
    → Multi-turn until task complete
```

### Model Priority (auto-fallback)

| Priority | Model | Purpose |
|----------|-------|---------|
| 1 | `openrouter/free` | Auto-routing across all free models |
| 2 | `qwen/qwen3-coder:free` | Code-optimized (480B params) |
| 3 | `deepseek/deepseek-chat:free` | General purpose |
| 4 | `meta-llama/llama-3.3-70b:free` | Large context (128K) |
| 5 | `google/gemma-4-26b-a4b-it:free` | Final fallback |

If a model returns 429 (rate limited) or 5xx, OpenRouter automatically tries the
next model. No manual intervention needed.

---

## Configuration Details

### `~/.config/opencode/opencode.json`

Key fields:

```json
{
  "model": "openrouter/openrouter/free",
  "small_model": "openrouter/nvidia/nemotron-3-nano-30b-a3b:free",
  "instructions": ["~/.config/opencode/AGENTS.md"],
  "provider": {
    "openrouter": {
      "env": ["OPENROUTER_API_KEY"],
      "options": {}
    }
  }
}
```

- **`model`**: Default model for OpenCode (OpenRouter auto-routing)
- **`small_model`**: Lightweight model for quick tasks
- **`instructions`**: AGENTS.md auto-loaded on startup
- **`provider.openrouter.env`**: Tells OpenCode which env var has the API key
- **Permissions**: Git operations auto-allowed, destructive commands blocked

### `/usr/local/bin/opencode` (Wrapper)

```bash
#!/usr/bin/env bash
set -e
KEY_FILE="/storage/emulated/0/Download/ai_openrouter/configs/api_key.json"
OPENCODE_REAL="/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe"

if [ -f "$KEY_FILE" ]; then
    export OPENROUTER_API_KEY=$(python3 -c "..." 2>/dev/null)
fi
exec "$OPENCODE_REAL" "$@"
```

The wrapper guarantees the API key is loaded before OpenCode starts, regardless
of shell profile, login state, or Termux restore.

---

## Backup & Restore

### Create a backup

```bash
cd opencode-termux
bash backup.sh
# Saves to: backups/opencode-backup-YYYYMMDD-HHMMSS/
```

Or to a custom location (e.g., SD card):

```bash
bash backup.sh /storage/emulated/0/backups
```

### Restore from backup

```bash
cd opencode-termux
bash restore.sh                    # latest backup
bash restore.sh backups/opencode-backup-20260101-120000  # specific
```

The backup includes:
- `~/.config/opencode/` (full config directory)
- API key file
- Wrapper script
- npm global package list
- OpenCode version info

---

## Troubleshooting

### "Missing Authentication header"

**Cause:** OpenCode started without `OPENROUTER_API_KEY` in the environment.

**Fix:**
1. Check the API key file: `cat /storage/emulated/0/Download/ai_openrouter/configs/api_key.json`
2. If missing or placeholder: `echo '{"key":"sk-or-...","saved":"..."}' > /storage/emulated/0/Download/ai_openrouter/configs/api_key.json`
3. Verify wrapper: `cat /usr/local/bin/opencode`
4. Restart: `opencode`

### "Command not found: opencode"

**Cause:** `/usr/local/bin/` is not in PATH.

**Fix:**
```bash
export PATH="/usr/local/bin:$PATH"
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
```

### "npm install fails / EACCES"

**Cause:** Termux permissions or npm cache issue.

**Fix:**
```bash
npm cache clean --force
pkg reinstall nodejs -y
npm install -g opencode-ai
```

### OpenCode starts but won't respond

**Cause:** OpenRouter rate limit or model unavailable.

**Fix:**
- Wait 60 seconds and retry
- Check model availability: https://openrouter.ai/models
- The auto-routing endpoint `openrouter/free` handles fallbacks automatically

### "ConfigInvalidError" on startup

**Cause:** Malformed `opencode.json`.

**Fix:**
```bash
python3 -c "import json; json.load(open('$HOME/.config/opencode/opencode.json'))"
# Fix any JSON errors reported
```

---

## API Key Setup

1. Get a free key at [https://openrouter.ai/keys](https://openrouter.ai/keys)
2. The installer will prompt you, or run:
   ```bash
   echo '{"key":"sk-or-your-key-here","saved":"2026-01-01T00:00:00"}' > /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
   ```
3. Verify:
   ```bash
   python3 -c "import json; print(json.load(open('/storage/emulated/0/Download/ai_openrouter/configs/api_key.json'))['key'][:12])"
   ```

The API key is stored in the shared `ai_openrouter` directory so both the
Termux AI TUI app and OpenCode can use it.

---

## Manual Installation Steps

If you prefer to install manually instead of using `install.sh`:

```bash
# 1. Install Node.js
pkg update -y && pkg install nodejs -y

# 2. Install OpenCode
npm install -g opencode-ai

# 3. Create config directory
mkdir -p ~/.config/opencode

# 4. Copy configs
cp configs/opencode.json ~/.config/opencode/opencode.json
cp AGENTS.md ~/.config/opencode/AGENTS.md

# 5. Install wrapper
cp scripts/opencode-wrapper.sh /usr/local/bin/opencode
chmod +x /usr/local/bin/opencode

# 6. Set API key
mkdir -p /storage/emulated/0/Download/ai_openrouter/configs
echo '{"key":"sk-or-...","saved":"2026-01-01T00:00:00"}' > /storage/emulated/0/Download/ai_openrouter/configs/api_key.json

# 7. Verify
opencode --version
```

---

## Portability

This setup is designed for easy recovery after:
- **Termux reinstall**: Clone repo, run `install.sh`, paste API key — 2 minutes
- **Factory reset**: Same process, backup first with `bash backup.sh`
- **New device**: Clone, install, restore from backup
- **Other Linux distros**: The wrapper and config work anywhere; just adjust
  `pkg install` to your package manager (`apt`, `dnf`, `pacman`)

---

## Files Referenced

| Path | Purpose |
|------|---------|
| `~/.config/opencode/opencode.json` | OpenCode global config (provider, model, permissions) |
| `~/.config/opencode/AGENTS.md` | Agent instructions (model priority, fallback rules) |
| `/usr/local/bin/opencode` | Wrapper script (executable, not symlink) |
| `/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe` | Real OpenCode binary |
| `/storage/emulated/0/Download/ai_openrouter/configs/api_key.json` | Shared API key (also used by Termux AI TUI) |
| `/tmp/opencode-active-model` | Persisted active model across sessions (created at runtime) |
