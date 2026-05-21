# OpenCode + OpenRouter — Termux → Ubuntu Proot Setup

One-command installer for **OpenCode** (AI coding assistant) connected to
**OpenRouter** (free model API gateway), running inside an **Ubuntu proot
container** on Android Termux.

```
opencode
  → loads API key from Android shared storage
  → connects to OpenRouter auto-routing endpoint
  → restores last session automatically
  → ready instantly — no manual setup
```

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Android Device                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  Termux (native Android app)              │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │  proot-distro                       │  │  │
│  │  │  ┌───────────────────────────────┐  │  │  │
│  │  │  │  Ubuntu 26.04 LTS (proot)     │  │  │  │
│  │  │  │  ┌─────────────────────────┐  │  │  │  │
│  │  │  │  │  Node.js 22 + npm       │  │  │  │  │
│  │  │  │  │  OpenCode (opencode-ai) │  │  │  │  │
│  │  │  │  │  Wrapper + Configs      │  │  │  │  │
│  │  │  │  └─────────────────────────┘  │  │  │  │
│  │  │  │                               │  │  │  │
│  │  │  │  API key: /storage/.. ↔ Android│  │  │  │
│  │  │  └───────────────────────────────┘  │  │  │
│  │  │  (shared via bind mount)            │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  │                                            │  │
│  │  /storage/emulated/0/Download/             │  │
│  │    ai_openrouter/configs/api_key.json      │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**Why Ubuntu/proot instead of native Termux?**
- OpenCode's Node.js runtime has better aarch64 compatibility on Ubuntu
- Full `apt` package manager with proper file paths
- Avoids Termux-specific ARM64 compatibility issues with some npm packages
- API key lives on Android storage so it survives Termux reinstallation

---

## Quick Install (Fresh Termux)

```bash
# 1. Update Termux packages
pkg update -y && pkg upgrade -y

# 2. Install git
pkg install git -y

# 3. Clone this repo
git clone https://github.com/Liaquatali123/opencode-termux.git
cd opencode-termux

# 4. Run installer
bash install.sh

# 5. Start coding
opencode
```

### What the installer does:

| Step | Action |
|------|--------|
| 1 | Detects Termux vs Ubuntu environment |
| 2 | Termux: installs `proot-distro` and Ubuntu 26.04 LTS |
| 3 | Copies repo into Ubuntu container |
| 4 | Runs `install.sh` inside Ubuntu |
| 5 | Ubuntu: installs Node.js 22 + npm via apt |
| 6 | Installs OpenCode globally via npm |
| 7 | Creates `~/.config/opencode/` with configs + AGENTS.md |
| 8 | Installs wrapper at `/usr/local/bin/opencode` |
| 9 | Prompts for OpenRouter API key |
| 10 | Creates Termux launcher that enters proot and runs opencode |
| 11 | Verifies everything |

---

## What Gets Installed

```
# Inside Ubuntu proot container:
/usr/local/bin/opencode                    → Wrapper (loads API key, execs real binary)
/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe → Real OpenCode binary
~/.config/opencode/opencode.json           → OpenCode config (provider, model, permissions)
~/.config/opencode/AGENTS.md               → Model priority list & fallback rules

# On Android shared storage (persists across Termux reinstalls):
/storage/emulated/0/Download/ai_openrouter/configs/api_key.json → API key

# In Termux (launcher that enters proot):
/data/data/com.termux/files/usr/bin/opencode → Launcher script
```

---

## Repository Structure

```
opencode-termux/
├── install.sh                  # One-command installer (detects Termux / Ubuntu)
├── backup.sh                   # Backup all configs + API key + metadata
├── restore.sh                  # Restore from backup
├── configs/
│   ├── opencode.json           # OpenCode configuration (OpenRouter provider)
│   └── api_key.json            # API key template (YOUR_OPENROUTER_API_KEY_HERE)
├── scripts/
│   └── opencode-wrapper.sh     # Wrapper source — reads key, exports env var, execs
├── AGENTS.md                   # Model priority list & fallback rules
├── backups/                    # Created by backup.sh (gitignored)
└── README.md                   # This file
```

---

## How OpenCode + OpenRouter Work Together

### Startup Flow

```
Termux shell:  opencode
    │
    ▼
/data/data/com.termux/files/usr/bin/opencode  (Termux launcher)
    │  exec proot-distro login ubuntu -- opencode
    ▼
Ubuntu proot:  /usr/local/bin/opencode  (wrapper script)
    │  Reads: /storage/emulated/0/.../api_key.json
    │  Exports: OPENROUTER_API_KEY
    ▼
Ubuntu proot:  opencode.exe  (real Node.js binary)
    │  Loads: ~/.config/opencode/opencode.json
    │  Reads: model = "openrouter/openrouter/free"
    │  Reads: provider.openrouter.env = ["OPENROUTER_API_KEY"]
    │  Reads: instructions = ["AGENTS.md"]
    ▼
OpenRouter API  (https://openrouter.ai/api/v1/chat/completions)
    │  Auth: Authorization: Bearer sk-or-...
    │  Auto-routes to best available free model
    ▼
Ready for coding — session restored, context intact
```

### Per-Request Flow

```
You type a message
    → OpenCode builds chat payload with conversation history
    → POST to OpenRouter with streaming enabled
    → OpenRouter auto-routes to available free model:
        Primary:   openrouter/free                  (auto-routing)
        Fallback:  qwen/qwen3-coder:free            (code-optimized)
        Fallback:  deepseek/deepseek-chat:free      (general purpose)
        Fallback:  meta-llama/llama-3.3-70b:free    (large context 128K)
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

## Environment Detection

The installer automatically detects where it's running:

| Environment | Detection | Action |
|-------------|-----------|--------|
| **Termux** | `/data/data/com.termux/files/usr/bin/pkg` exists | Install proot-distro + Ubuntu, copy repo, re-run inside Ubuntu |
| **Ubuntu (proot)** | `/etc/os-release` contains `ubuntu` | Install Node.js, OpenCode, configs, wrapper |
| **Other Linux** | Neither of the above | Run generic Linux setup (requires apt) |

---

## Configuration Details

### `~/.config/opencode/opencode.json`

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

| Field | Purpose |
|-------|---------|
| `model` | Default AI model (OpenRouter auto-routing) |
| `small_model` | Lightweight model for quick tasks |
| `instructions` | AGENTS.md auto-loaded on every startup |
| `provider.openrouter.env` | Tells OpenCode which env var holds the API key |

### `/usr/local/bin/opencode` (Wrapper)

The wrapper is a bash script that runs before OpenCode. It:
1. Reads the API key from Android storage (`/storage/emulated/0/.../api_key.json`)
2. Falls back to local key file if Android storage isn't mounted
3. Exports `OPENROUTER_API_KEY` into the environment
4. **Injects the API key into provider options via `OPENCODE_CONFIG_CONTENT`**
   (the `env` field in config only lists the env var name — it doesn't pass the
   value to HTTP headers; explicit `apiKey` in options fixes this)
5. Execs the real OpenCode binary

```bash
if [ -n "$API_KEY" ]; then
    export OPENROUTER_API_KEY="$API_KEY"
    export OPENCODE_CONFIG_CONTENT='{"provider":{"openrouter":{"options":{"apiKey":"'"$API_KEY"'"}}}}'
fi
exec "$OPENCODE_REAL" "$@"
```

**Why `OPENCODE_CONFIG_CONTENT`?**
OpenCode's `openrouter` provider detects the `OPENROUTER_API_KEY` env var but
does NOT automatically include it as an `Authorization` header in API requests.
The `env` config field only tells opencode "this env var exists" — it doesn't
inject its value into the HTTP client. By setting `options.apiKey` via
`OPENCODE_CONFIG_CONTENT`, the provider receives the key in the format it
actually uses for authentication.

---

## Backup & Restore

### Create a backup

```bash
cd opencode-termux
bash backup.sh
# Saves to: backups/opencode-backup-YYYYMMDD-HHMMSS/
```

Or save to Android SD card (survives Termux reinstall):

```bash
bash backup.sh /storage/emulated/0/backups
```

**Backup includes:**
- `~/.config/opencode/` (full config directory)
- API key file (from Android storage or local)
- Wrapper script at `/usr/local/bin/opencode`
- Ubuntu proot-distro metadata
- npm global package list
- OpenCode version + paths
- System info (architecture, OS release)

### Restore from backup

```bash
# On fresh Termux:
pkg install git -y
git clone https://github.com/Liaquatali123/opencode-termux.git
cd opencode-termux
bash restore.sh                    # auto-detect latest backup
bash restore.sh /path/to/backup    # specific backup
```

**Restore includes:**
- Re-creates `~/.config/opencode/` with all configs
- Restores API key to Android storage
- Restores wrapper script
- Installs Node.js if missing
- Reinstalls OpenCode if missing
- Refreshes wrapper binary path

---

## Fresh Install After Factory Reset

```bash
# 1. Install Termux from F-Droid or GitHub releases
# 2. Open Termux and run:
pkg update -y && pkg upgrade -y
pkg install git -y

# 3. Clone and install
git clone https://github.com/Liaquatali123/opencode-termux.git
cd opencode-termux
bash install.sh

# 4. Start coding
opencode
```

**Total time: ~5 minutes** (most of it waiting for Ubuntu to install).

---

## Troubleshooting

### "Missing Authentication header"

**Cause:** OpenCode's `openrouter` provider didn't receive the API key in
`options.apiKey`. The env var is detected but not passed to HTTP headers.

**Fix:**
```bash
# 1. Check the API key file exists
cat /storage/emulated/0/Download/ai_openrouter/configs/api_key.json

# 2. Verify wrapper injects key via OPENCODE_CONFIG_CONTENT:
cat /usr/local/bin/opencode
# Should contain: export OPENCODE_CONFIG_CONTENT='{"provider":{"openrouter":{"options":{"apiKey":"...'

# 3. Test auth directly:
curl -s -o /dev/null -w "HTTP %{http_code}" \
  -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $(cat /storage/emulated/0/Download/ai_openrouter/configs/api_key.json | python3 -c 'import json,sys;print(json.load(sys.stdin)[\"key\"])')" \
  -H "Content-Type: application/json" \
  -d '{"model":"openrouter/free","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'
# HTTP 200 = auth works, HTTP 429/5xx = key valid but rate-limited

# 4. If auth still fails, reinstall wrapper:
bash install.sh
```

### "Command not found: opencode"

**Cause:** `/usr/local/bin/` not in PATH.

**Fix:**
```bash
export PATH="/usr/local/bin:$PATH"
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
```

### OpenCode doesn't start from Termux

**Cause:** Ubuntu proot container not installed or launcher missing.

**Fix:**
```bash
# Enter Ubuntu manually:
proot-distro login ubuntu

# Inside Ubuntu, check opencode:
which opencode
opencode --version

# If missing, reinstall from inside Ubuntu:
cd /root/opencode-termux
bash install.sh --inside-ubuntu
```

### "proot-distro: command not found"

**Cause:** Running in Termux but proot-distro not installed.

**Fix:**
```bash
pkg install proot-distro -y
```

### "npm install fails / EACCES"

**Cause:** npm permission issue.

**Fix:**
```bash
npm cache clean --force
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

### Android storage not accessible inside proot

**Cause:** The `/storage/emulated/0/` mount point isn't set up in the proot.

**Fix:**
```bash
# From Termux, restart proot-distro with bind mount:
proot-distro login ubuntu

# If still missing, the default proot-distro setup should include it.
# Restart Termux app completely if it's broken.
```

---

## API Key Setup

1. Get a free key at [https://openrouter.ai/keys](https://openrouter.ai/keys)
2. The installer will prompt you, or set it manually:
   ```bash
   mkdir -p /storage/emulated/0/Download/ai_openrouter/configs
   echo '{"key":"sk-or-your-key-here","saved":"2026-01-01T00:00:00"}' \
     > /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
   ```
3. Verify:
   ```bash
   python3 -c "import json; \
     k=json.load(open('/storage/emulated/0/Download/ai_openrouter/configs/api_key.json'))['key']; \
     print(k[:12]+'...')"
   ```

The API key is stored on Android shared storage so it survives:
- Termux app reinstallation
- proot-distro container rebuilds
- Ubuntu reinstallation
- Only a factory reset would wipe it

---

## Manual Installation Steps

If you prefer to install manually without `install.sh`:

### Termux side:

```bash
pkg update -y && pkg install proot-distro nodejs -y
proot-distro install ubuntu
proot-distro login ubuntu
```

### Ubuntu side (inside proot):

```bash
apt update && apt install nodejs npm -y
npm install -g opencode-ai

# Config
mkdir -p ~/.config/opencode
# Copy configs/opencode.json and AGENTS.md from repo

# Wrapper
mkdir -p /usr/local/bin
cat > /usr/local/bin/opencode << 'EOF'
#!/usr/bin/env bash
set -e
OPENCODE_REAL="/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe"
KEY_FILE="/storage/emulated/0/Download/ai_openrouter/configs/api_key.json"
if [ -f "$KEY_FILE" ]; then
  export OPENROUTER_API_KEY=$(python3 -c "import json; print(json.load(open('$KEY_FILE')).get('key',''))" 2>/dev/null)
fi
exec "$OPENCODE_REAL" "$@"
EOF
chmod +x /usr/local/bin/opencode

# API key
mkdir -p /storage/emulated/0/Download/ai_openrouter/configs
echo '{"key":"sk-or-...","saved":"2026-01-01T00:00:00"}' \
  > /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
```

### Termux launcher:

```bash
cat > /data/data/com.termux/files/usr/bin/opencode << 'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login ubuntu -- bash -c "export HOME=/root && cd ~ && exec opencode \"$@\""
LAUNCHER
chmod +x /data/data/com.termux/files/usr/bin/opencode
```

---

## Portability

This setup is designed for easy recovery after any disaster:

| Scenario | Recovery Steps |
|----------|---------------|
| **Termux reinstalled** | Clone repo, run `install.sh`, paste API key — ~5 min |
| **Phone factory reset** | Backup first with `bash backup.sh /sdcard/`, then restore after setup |
| **New device** | Install Termux, clone repo, `bash install.sh` |
| **Proot Ubuntu broken** | `proot-distro remove ubuntu && proot-distro install ubuntu`, then re-run installer |
| **Other Linux (non-Termux)** | Clone repo, `bash install.sh` (skips proot, installs directly) |

**Key to portability:** The API key is stored on Android's shared storage
(`/storage/emulated/0/`), which persists across Termux reinstalls. Even if
Termux is deleted and reinstalled, the key file remains on the device.

---

## Files Referenced

| Path | Location | Purpose |
|------|----------|---------|
| `~/.config/opencode/opencode.json` | Ubuntu proot | OpenCode global config (provider, model, permissions) |
| `~/.config/opencode/AGENTS.md` | Ubuntu proot | Agent instructions (model priority, fallback rules) |
| `/usr/local/bin/opencode` | Ubuntu proot | Wrapper script (executable, reads API key, execs real binary) |
| `/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe` | Ubuntu proot | Real OpenCode Node.js binary |
| `/storage/emulated/0/Download/ai_openrouter/configs/api_key.json` | Android storage | Shared API key (survives Termux reinstall) |
| `/data/data/com.termux/files/usr/bin/opencode` | Termux | Launcher that enters proot and runs opencode |
| `/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/` | Termux | Ubuntu proot container rootfs |
| `/tmp/opencode-active-model` | Ubuntu proot | Persisted active model across sessions (created at runtime) |
