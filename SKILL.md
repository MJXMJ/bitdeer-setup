---
name: bitdeer-setup
description: Set up the Bitdeer AI inference API as a pi model provider and run zai-org/GLM-5.3 (plus GLM-5.3-Flash, Kimi-K3, and DeepSeek models). Use when configuring api-inference.bitdeer.ai in pi, adding Bitdeer models to models.json, authenticating with a Bitdeer API key, or troubleshooting Bitdeer/GLM provider errors.
compatibility: Requires the pi coding agent, a Bitdeer AI API key (https://cloud.bitdeer.ai), jq, and curl.
metadata:
  provider: bitdeer
  endpoint: https://api-inference.bitdeer.ai/v1
  primary-model: zai-org/GLM-5.3
---

# Bitdeer GLM-5.3 Setup

Configure [Bitdeer AI](https://cloud.bitdeer.ai)'s OpenAI-compatible inference endpoint as a pi provider and run `zai-org/GLM-5.3` — a reasoning model that streams GLM-style `reasoning_content` — inside pi.

## Security Rules

- **Never commit the API key.** It lives only in:
  - the gitignored `.env` file next to this skill, and/or
  - `~/.pi/agent/models.json` on the local machine (outside any git repo).
- `.env` is listed in `.gitignore`; `.env.example` (committed) contains only a placeholder.
- If a key is ever committed or exposed, rotate it in the Bitdeer console immediately.

## Prerequisites

1. **pi** coding agent installed
2. **jq** and **curl** (`brew install jq curl` on macOS)
3. A **Bitdeer AI API key**: sign in at https://cloud.bitdeer.ai → API Keys → Create Key

## Setup

### Option A — automated (recommended)

```bash
cd /path/to/bitdeer-setup
cp .env.example .env   # edit .env and paste your key
./scripts/setup.sh     # merges the bitdeer provider into ~/.pi/agent/models.json
```

The script:

- reads the key from `$BITDEER_API_KEY` or `.env` (prompts if neither is set)
- creates `~/.pi/agent/models.json` if needed; writes a timestamped backup if it exists
- merges the provider config below and sets file permissions to `600`
- never writes the key anywhere inside this repository

Use `./scripts/setup.sh --use-env-var` to store the string `$BITDEER_API_KEY` in `models.json` instead of the literal key (then `export BITDEER_API_KEY=...` in your shell profile so pi resolves it at request time).

### Option B — manual

Add this to `~/.pi/agent/models.json` (create the file if it doesn't exist), replacing the apiKey value with your own key:

```json
{
  "providers": {
    "bitdeer": {
      "baseUrl": "https://api-inference.bitdeer.ai/v1",
      "api": "openai-completions",
      "apiKey": "YOUR_BITDEER_API_KEY",
      "models": [
        {
          "id": "zai-org/GLM-5.3",
          "name": "GLM-5.3 (Bitdeer)",
          "reasoning": true,
          "compat": { "supportsReasoningEffort": true }
        },
        { "id": "zai-org/GLM-5.3-Flash" },
        { "id": "moonshotai/Kimi-K3", "contextWindow": 1048576 },
        { "id": "deepseek-ai/DeepSeek-V4-Flash" },
        { "id": "deepseek-ai/DeepSeek-V4.1-Flash" },
        { "id": "Qwen/Qwen3.8-27B" }
      ]
    }
  }
}
```

If the file already has other providers, add or replace only the `"bitdeer"` block under `"providers"`. The file reloads every time you open `/model` — no restart needed.

## Use the Model

```bash
pi --model bitdeer/zai-org/GLM-5.3   # start pi directly on GLM-5.3
pi --list-models | grep -i bitdeer   # confirm the provider loaded
```

Inside a session: `/model` → pick `zai-org/GLM-5.3`. With `reasoning: true` and `compat.supportsReasoningEffort`, pi's thinking levels (off…max) map to the OpenAI-style `reasoning_effort` parameter, which Bitdeer accepts for GLM-5.3:

```bash
pi --model bitdeer/zai-org/GLM-5.3 --thinking high
```

## Verify

```bash
./scripts/verify.sh
```

Checks the key against `GET /v1/models`, lists the live model catalog, and runs a one-line test completion on `zai-org/GLM-5.3`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `401` / invalid API key | Key wrong or revoked — check `.env` / `models.json`; create a new key in the Bitdeer console |
| Models missing from `/model` | Typo in a model `id`; run `./scripts/verify.sh` to list live ids from the endpoint |
| `invalid request` errors | Bitdeer rejects z.ai-style `thinking: {...}` parameters; it accepts `reasoning_effort` instead — keep `compat.supportsReasoningEffort: true` and do **not** set `thinkingFormat: "zai"` |
| Thinking output missing | GLM-5.3 reasons by default; if `reasoning_content` stops appearing, re-run `./scripts/verify.sh` to inspect the raw response |
| Context overflow | GLM-5.3 uses pi's safe default `contextWindow: 128000`; lower it if the endpoint rejects large requests |

See [references/bitdeer-api.md](references/bitdeer-api.md) for the full endpoint reference, verified request/response behavior, and the complete model catalog.
