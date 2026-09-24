# Bitdeer AI API Reference

Details for the Bitdeer AI inference API as used by this skill. Behavior below was
verified directly against the live endpoint on 2026-09-24; re-check with
`./scripts/verify.sh` if something changes.

## Endpoint & Authentication

| Item | Value |
|---|---|
| Base URL | `https://api-inference.bitdeer.ai/v1` |
| API type | OpenAI Chat Completions compatible |
| Auth | `Authorization: Bearer <BITDEER_API_KEY>` header |
| API keys | Created at https://cloud.bitdeer.ai → API Keys |

## Chat Completions

Minimal request:

```bash
curl https://api-inference.bitdeer.ai/v1/chat/completions \
  -H "Authorization: Bearer $BITDEER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "zai-org/GLM-5.3",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

Response shape (non-streaming):

```json
{
  "model": "zai-org/GLM-5.3",
  "choices": [{
    "finish_reason": "stop",
    "message": {
      "content": "OK",
      "reasoning_content": "The user wants me to reply with exactly \"OK\"..."
    }
  }],
  "usage": {
    "prompt_tokens": 17,
    "completion_tokens": 17,
    "reasoning_tokens": 15,
    "total_tokens": 34,
    "prompt_tokens_details": { "cached_tokens": 0 }
  }
}
```

- `reasoning_content` carries GLM-style thinking; pi renders it as thinking blocks.
- `usage.reasoning_tokens` reports thinking token usage separately.
- Streaming follows the OpenAI SSE format (`stream: true`), including
  `reasoning_content` deltas.

## Verified Behavior Matrix

| Feature | Status | Notes |
|---|---|---|
| `GET /v1/models` | ✅ works | Returns the live catalog (see below) |
| `POST /v1/chat/completions` | ✅ works | Streaming and non-streaming |
| `developer` role | ✅ accepted | pi's system prompt role for reasoning models is fine |
| `reasoning_effort` | ✅ accepted | OpenAI-style values (e.g. `"low"`); reduces `reasoning_tokens` |
| `reasoning_content` | ✅ returned | GLM-5.3 reasons by default |
| `max_tokens` | ✅ accepted | No cap enforced at least up to 999999 |
| z.ai-style `thinking: {"type": "disabled"}` | ❌ rejected | Fails with `invalid request` — do **not** use `thinkingFormat: "zai"` in pi |

## Model Catalog (observed 2026-09-24)

Chat models configured in this skill:

| Model ID | Notes |
|---|---|
| `zai-org/GLM-5.3` | Primary model; reasoning by default, `reasoning_effort` supported |
| `zai-org/GLM-5.3-Flash` | Faster GLM variant |
| `moonshotai/Kimi-K3` | Long context; configured with `contextWindow: 1048576` |
| `deepseek-ai/DeepSeek-V4-Flash` | |
| `deepseek-ai/DeepSeek-V4.1-Flash` | |
| `Qwen/Qwen3.8-27B` | |

Also present on the endpoint but **not** chat models (not configured in pi):
`BAAI/bge-m3` (embeddings), `BAAI/bge-reranker-v2-m3` (reranker),
`seedream-5.0-lite` (image generation).

Fetch the current list at any time:

```bash
curl -s https://api-inference.bitdeer.ai/v1/models \
  -H "Authorization: Bearer $BITDEER_API_KEY" | jq -r '.data[].id'
```

## pi Agent Installation & Configuration

- **Install:** `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`
  (alternative: `curl -fsSL https://pi.dev/install.sh | sh`)
- **Requires:** Node.js ≥ 22.19 (`node --version`). On EACCES with global npm
  installs, use nvm or the curl installer.
- **Provider config:** `~/.pi/agent/models.json` (this skill's `setup.sh` writes it).
  Reloads whenever `/model` is opened — no restart required.
- **Startup default:** `~/.pi/agent/settings.json` —

  ```json
  {
    "defaultProvider": "bitdeer",
    "defaultModel": "zai-org/GLM-5.3"
  }
  ```

  Plain `pi` then starts on GLM-5.3. (`setup.sh --set-default` writes this,
  preserving existing settings; equivalently press Ctrl+S in the `/model` picker.)
- **Non-interactive smoke test:**
  `pi --no-session -p --model bitdeer/zai-org/GLM-5.3 "Reply with exactly: OK"`
- **apiKey in models.json** supports three forms:
  - literal: `"bd-..."`
  - environment reference: `"$BITDEER_API_KEY"` or `"${BITDEER_API_KEY}"` (resolved at request time; the variable must be in pi's environment)
  - shell command: `"!security find-generic-password -ws bitdeer"` (stdout is used)
- Recommended GLM-5.3 model entry:

  ```json
  {
    "id": "zai-org/GLM-5.3",
    "name": "GLM-5.3 (Bitdeer)",
    "reasoning": true,
    "compat": { "supportsReasoningEffort": true }
  }
  ```

  `reasoning: true` makes pi show thinking controls; pi's thinking levels
  (off…max) map to `reasoning_effort`, which the endpoint accepts. Unspecified
  fields fall back to pi defaults (`contextWindow: 128000`, `maxTokens: 16384`).

## Security

- The API key must never be committed. Local storage locations:
  - `.env` in the skill root (gitignored)
  - `~/.pi/agent/models.json` (outside any git repo; `setup.sh` sets it to mode `600`)
- Rotate the key in the Bitdeer console immediately if it is ever exposed.
