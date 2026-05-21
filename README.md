# OpenCode + OpenRouter — Termux → Ubuntu Proot

**One-command installer** that sets up OpenCode (AI coding assistant) with
OpenRouter (free model API gateway) inside an Ubuntu proot container on
Android Termux.

```
pkg install git -y
git clone https://github.com/Liaquatali123/opencode-termux.git
cd opencode-termux
bash install.sh
opencode
```

---

## Architecture

```
Android Phone
  └── Termux (native app)
        └── proot-distro
              └── Ubuntu 26.04 LTS (proot container)
                    ├── Node.js 22 + npm
                    ├── OpenCode (opencode-ai npm package)
                    ├── /usr/local/bin/opencode  (wrapper)
                    └── ~/.config/opencode/
                          ├── opencode.json
                          └── AGENTS.md
```

**Why not install OpenCode directly in Termux?**
- OpenCode's Node.js runtime has better aarch64 compatibility on Ubuntu
- Full `apt` package manager avoids Termux-specific ARM64 issues
- The proot container provides a complete Linux filesystem

**API key lives on Android storage** (`/storage/emulated/0/.../api_key.json`),
shared between Termux and the Ubuntu proot, so it survives Termux reinstalls.

---

## Fresh Termux Install

```bash
# 1. Update Termux
pkg update -y && pkg upgrade -y

# 2. Install git
pkg install git -y

# 3. Clone repo
git clone https://github.com/Liaquatali123/opencode-termux.git
cd opencode-termux

# 4. Run installer (fully automated)
bash install.sh

# 5. Done — start coding
opencode
```

### What the installer does

| Step | Action |
|------|--------|
| 1 | Detects if running in Termux or Ubuntu |
| 2 | **Termux mode:** Installs proot-distro + Ubuntu 26.04, copies repo into container, re-runs installer inside Ubuntu |
| 3 | **Ubuntu mode:** Updates apt, installs Node.js 22 + npm |
| 4 | Installs OpenCode globally via npm (`opencode-ai`) |
| 5 | Creates `~/.config/opencode/opencode.json` with OpenRouter provider config |
| 6 | Copies AGENTS.md (model priority list, fallback rules) |
| 7 | Installs wrapper at `/usr/local/bin/opencode` — reads API key, injects auth header |
| 8 | Auto-detects existing API key on Android storage (no re-prompt) |
| 9 | Creates Termux launcher so `opencode` command enters proot automatically |
| 10 | Tests OpenRouter API connection |
| 11 | Verifies all components |

---

## How It Works

### Startup flow: `opencode`

```
User types: opencode
    │
    ▼
Termux shell → /data/data/com.termux/files/usr/bin/opencode (launcher)
    │  Exec: proot-distro login ubuntu -- opencode
    ▼
Ubuntu proot → /usr/local/bin/opencode (wrapper)
    │  1. Reads API key from Android storage
    │  2. Exports OPENROUTER_API_KEY
    │  3. Injects key into provider options via OPENCODE_CONFIG_CONTENT
    │     → fixes "Missing Authentication header" bug
    │  4. Execs real binary
    ▼
Ubuntu proot → opencode.exe (real Node.js binary)
    │  Loads ~/.config/opencode/opencode.json
    │  Connects to OpenRouter auto-routing endpoint
    ▼
Ready for coding — session restored, authenticated, no manual input
```

### Per-request flow

```
You type a message
    → OpenCode builds payload with conversation history
    → POST https://openrouter.ai/api/v1/chat/completions
    → Headers: Authorization: Bearer sk-or-...
    → OpenRouter auto-routes to best available free model
    → Streamed response parsed → tool calls executed → results fed back
```

### Model priority (auto-fallback)

| Priority | Model | Purpose |
|----------|-------|---------|
| 1 | `openrouter/free` | Auto-routing across all free models |
| 2 | `qwen/qwen3-coder:free` | Code-optimized (480B params) |
| 3 | `deepseek/deepseek-chat:free` | General purpose |
| 4 | `meta-llama/llama-3.3-70b:free` | Large context (128K) |
| 5 | `google/gemma-4-26b-a4b-it:free` | Final fallback |

---

## Repository Structure

```
opencode-termux/
├── install.sh                     # One-command installer (Termux + Ubuntu)
├── backup.sh                      # Backup configs, API key, proot metadata
├── restore.sh                     # Restore from backup
├── configs/
│   ├── opencode.json              # OpenCode config (OpenRouter provider)
│   └── api_key.json               # API key template
├── scripts/
│   └── opencode-wrapper.sh        # Wrapper: loads API key, injects auth
├── AGENTS.md                      # Model priority & fallback rules
├── backups/                       # Created by backup.sh
└── README.md                      # This file
```

---

## Configuration Files

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

### `/usr/local/bin/opencode` (wrapper)

The wrapper is the **critical component** that makes OpenRouter auth work:

```bash
# 1. Read API key from Android storage
API_KEY=$(python3 -c "import json; print(json.load(open('KEY_FILE')).get('key',''))")

# 2. Inject into provider options (this is what fixes auth)
export OPENCODE_CONFIG_CONTENT='{"provider":{"openrouter":{"options":{"apiKey":"KEY"}}}}'

# 3. Exec real binary
exec "$OPENCODE_REAL" "$@"
```

**Why is this needed?** OpenCode's `openrouter` provider detects the
`OPENROUTER_API_KEY` env var (shows it in `opencode providers list`) but does
NOT automatically include it as an HTTP `Authorization` header. By setting
`options.apiKey` via `OPENCODE_CONFIG_CONTENT`, the provider receives the key
in the format it actually uses for authentication.

---

## Backup & Restore

### Backup

```bash
cd opencode-termux
bash backup.sh
# → backups/opencode-backup-YYYYMMDD-HHMMSS/
```

Or save to SD card (survives Termux reinstall):

```bash
bash backup.sh /storage/emulated/0/backups
```

### Restore

```bash
cd opencode-termux
bash restore.sh                    # latest backup
bash restore.sh /path/to/backup    # specific
```

**Restore includes:** config dir, API key, wrapper, proot metadata, npm packages.

---

## Recovery After Factory Reset

```bash
# Install Termux → open it → run:
pkg update -y && pkg upgrade -y
pkg install git -y
git clone https://github.com/Liaquatali123/opencode-termux.git
cd opencode-termux
bash install.sh
opencode
```

**Total time: ~5 minutes.** The API key survives on Android storage if you
didn't wipe it. Otherwise the installer prompts for a new one.

---

## Troubleshooting

### "Missing Authentication header"

**Cause:** `OPENCODE_CONFIG_CONTENT` was not set — the openrouter provider
doesn't include the auth header without explicit `options.apiKey`.

**Fix:**
```bash
# 1. Check wrapper
cat /usr/local/bin/opencode | grep OPENCODE_CONFIG_CONTENT

# 2. Verify API key file
cat /storage/emulated/0/Download/ai_openrouter/configs/api_key.json

# 3. Reinstall wrapper
cd opencode-termux && bash install.sh --inside-ubuntu
```

### "Command not found: opencode"

**Fix:**
```bash
export PATH="/usr/local/bin:$PATH"
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
```

### "proot-distro: command not found"

**Fix:** Run from Termux, not inside the proot:
```bash
pkg install proot-distro -y
```

### OpenCode starts but won't respond

**Cause:** OpenRouter rate limit or model unavailable.

**Fix:**
- Wait 60 seconds and retry
- Check model status: `curl -s https://openrouter.ai/api/v1/models | python3 -m json.tool | grep free`
- The auto-routing endpoint handles fallbacks automatically

### API key file missing

**Fix:**
```bash
mkdir -p /storage/emulated/0/Download/ai_openrouter/configs
echo '{"key":"sk-or-your-key","saved":"2026-01-01T00:00:00"}' \
  > /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
```

### "ConfigInvalidError" on startup

**Fix:**
```bash
python3 -c "import json; json.load(open('$HOME/.config/opencode/opencode.json'))"
# Check and fix JSON syntax if error reported
```

---

## API Key Setup

1. Get a free key at [https://openrouter.ai/keys](https://openrouter.ai/keys)
2. The installer prompts you, or set manually:
   ```bash
   mkdir -p /storage/emulated/0/Download/ai_openrouter/configs
   echo '{"key":"sk-or-your-key","saved":"2026-01-01T00:00:00"}' \
     > /storage/emulated/0/Download/ai_openrouter/configs/api_key.json
   ```
3. Verify:
   ```bash
   python3 -c "import json; \
     k=json.load(open('/storage/emulated/0/Download/ai_openrouter/configs/api_key.json'))['key']; \
     print(k[:12]+'...')"
   ```

The API key lives on **Android shared storage** — it survives Termux reinstalls,
proot container rebuilds, and Ubuntu reinstallation. Only a factory reset wipes it.

---

## Files Referenced

| Path | Location | Purpose |
|------|----------|---------|
| `~/.config/opencode/opencode.json` | Ubuntu proot | OpenCode global config |
| `~/.config/opencode/AGENTS.md` | Ubuntu proot | Model priority + fallback rules |
| `/usr/local/bin/opencode` | Ubuntu proot | Wrapper (loads key, injects auth, execs binary) |
| `/usr/local/lib/node_modules/opencode-ai/bin/opencode.exe` | Ubuntu proot | Real OpenCode binary |
| `/storage/emulated/0/Download/ai_openrouter/configs/api_key.json` | Android storage | Shared API key (survives reinstalls) |
| `/data/data/com.termux/files/usr/bin/opencode` | Termux | Launcher → enters proot → runs opencode |
| `/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/` | Termux | Ubuntu proot container rootfs |
