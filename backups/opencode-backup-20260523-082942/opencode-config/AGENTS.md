# OpenRouter Free Model Fallback System

## Model Availability (verified 2026-05-22)
- `openrouter/free` — ✅ Auto-routing (intermittent 404 on some providers)
- `qwen/qwen3-coder:free` — ⏳ 429 daily rate limit exhausted
- `deepseek/deepseek-chat:free` — ❌ 404 Model not found (deprecated)
- `meta-llama/llama-3.3-70b-instruct:free` — ⏳ 429 daily rate limit exhausted
- `google/gemma-4-26b-a4b-it:free` — ⏳ 429 daily rate limit exhausted
- `nvidia/nemotron-3-nano-30b-a3b:free` — ⏳ 429 daily rate limit exhausted

## Transient Error Handling
- `[OpenInference] Model not found` = OpenRouter auto-routing chose a provider
  that doesn't have the model. This is transient — retry the same command.
- If `openrouter/free` fails, wait 10-30s and retry. Routing changes per request.

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
