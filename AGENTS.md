# OpenRouter Free Model Fallback System

## Model Priority (auto-fallback order)
1. `openrouter/free` (auto-routes across free models) ✅ Working
2. `qwen/qwen3-coder:free` (code-optimized, 480B params) ⏳ May be rate-limited
3. `deepseek/deepseek-v4-flash:free` (fast inference) ⏳ May be rate-limited
4. `meta-llama/llama-3.3-70b-instruct:free` (large context 128K) ⏳ May be rate-limited
5. `google/gemma-4-26b-a4b-it:free` (fallback) ⏳ May be rate-limited

## Fallback Behavior
- If the current model returns a 429 (rate limit) or 5xx error, automatically switch to next model
- The active model is persisted in `/tmp/opencode-active-model`
- On session restart, the last working model is used
- No manual intervention needed

## Coding Optimization
- Prefer concise responses (minimize tokens)
- Use single-file solutions when possible
- Use built-in tools over bash commands
- Batch independent operations in parallel
- Keep context lean: avoid large file reads unless necessary

## OpenRouter Setup
- API endpoint: `https://openrouter.ai/api/v1/chat/completions`
- Auth: `Authorization: Bearer $OPENROUTER_API_KEY`
- Default model in opencode config: `openrouter/openrouter/free` (auto-routing)
- API key stored at: `/storage/emulated/0/Download/ai_openrouter/configs/api_key.json`
  (Android storage, accessible from both Termux and Ubuntu proot)

## Architecture
- Android → Termux → proot-distro → Ubuntu 26.04 LTS → OpenCode
- OpenCode and Node.js run inside the Ubuntu proot container
- The API key file lives on the Android shared storage, mounted at
  `/storage/emulated/0/` inside both Termux and the Ubuntu proot
- The wrapper script at `/usr/local/bin/opencode` reads the key from Android
  storage before launching OpenCode

## Provider Configuration
OpenCode uses the `openrouter` provider with env-var-based auth:
```json
"provider": {
  "openrouter": {
    "env": ["OPENROUTER_API_KEY"],
    "options": {}
  }
}
```
The wrapper script at `/usr/local/bin/opencode` loads the key from the shared
config file before OpenCode starts, ensuring the env var is always present.
