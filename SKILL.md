---
name: bitdeer-setup
description: End-to-end setup of the pi coding agent with the Bitdeer AI provider and zai-org/GLM-5.3 on a new machine. Installs pi and prerequisites (Node.js, jq), configures the bitdeer provider in ~/.pi/agent/models.json, wires up the Bitdeer API key (real key or placeholder), sets GLM-5.3 as the startup default, and verifies live. Use when asked to install or configure pi with Bitdeer/GLM-5.3, move this setup to a new machine, or troubleshoot it.
compatibility: macOS or Linux. Needs Node.js >= 22.19, npm, curl, jq, and bash — this runbook installs any that are missing.
metadata:
  provider: bitdeer
  endpoint: https://api-inference.bitdeer.ai/v1
  primary-model: zai-org/GLM-5.3
---

# Bitdeer GLM-5.3 Setup — Agent Runbook

You (the executing agent — Claude, pi, or any other) are setting up the **pi coding
agent** with the **Bitdeer AI** provider so the user can run **`zai-org/GLM-5.3`**.
The user does nothing hands-on: you perform every step below and involve the user
only to supply the Bitdeer API key (Step 3).

This repository **is** the skill. All relative paths are relative to its root
(the directory containing this `SKILL.md`). On the target machine it can live
anywhere, e.g. `~/bitdeer-setup`, or in a skills directory for auto-discovery
(`~/.claude/skills/bitdeer-setup` for Claude Code, `~/.pi/agent/skills/bitdeer-setup` for pi).

## Target State

When you are done, all of the following are true:

1. Node.js ≥ 22.19, npm, curl, and jq are installed
2. pi is installed globally (`pi --version` works)
3. `~/.pi/agent/models.json` has a `bitdeer` provider with GLM-5.3 (reasoning) + 5 more models
4. The API key exists only in `<repo>/.env` (gitignored) and `~/.pi/agent/models.json` (mode 600)
5. pi's startup default is bitdeer / `zai-org/GLM-5.3` (`~/.pi/agent/settings.json`)
6. Live verification passed: `./scripts/verify.sh` and the `pi -p` smoke test

## Ground Rules

- **The API key is a secret.** Never echo it in full, never commit it, never write it
  anywhere except `<repo>/.env` and `~/.pi/agent/models.json`. `.env` is gitignored.
- Run the steps in order. If a check fails, fix it or ask the user — do not skip ahead.
- Never modify providers other than `bitdeer` in `models.json`; preserve unrelated
  settings in `settings.json`. Both scripts back up before writing.
- Report one line of progress to the user after each step.

## Step 1 — Preflight

Check what is already present:

```bash
uname -s                                  # Darwin (macOS) or Linux
node --version 2>/dev/null                # need >= v22.19.0
npm --version 2>/dev/null
curl --version 2>/dev/null | head -1
jq --version 2>/dev/null
pi --version 2>/dev/null
```

Install only what is missing:

- **macOS:** `brew install node jq` (install Homebrew from https://brew.sh first if needed; curl ships with macOS)
- **Debian/Ubuntu:** `sudo apt-get update && sudo apt-get install -y curl jq`
- **Node.js:** pi requires Node ≥ 22.19. If missing or older, install Node 22 via nvm
  (works on macOS and Linux, no sudo, avoids npm EACCES issues):

  ```bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh"
  nvm install 22
  ```

Re-run the checks; `node --version` must print v22.19.0 or newer.

## Step 2 — Install pi

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
pi --version
```

- If npm global installs fail with `EACCES`, use nvm (above) or the standalone
  installer: `curl -fsSL https://pi.dev/install.sh | sh`
- If pi is already installed, keep it (optionally `pi update --self`).

## Step 3 — API Key (the only user interaction)

Ask the user once: **"Do you have your Bitdeer API key ready?"**
(Keys are created at https://cloud.bitdeer.ai → API Keys.)

**Flow A — key available now.** The user pastes the key in chat or has already
placed it in `<repo>/.env`. Write it to `.env` (never print it back; confirm using
only its first 4 characters):

```bash
printf 'BITDEER_API_KEY=<the-key>\n' > .env && chmod 600 .env
```

**Flow B — no key yet.** Create the placeholder and continue — everything else
works without the key:

```bash
cp .env.example .env && chmod 600 .env    # contains BITDEER_API_KEY=your-bitdeer-api-key
```

Tell the user exactly how to finish later:

> Replace the `BITDEER_API_KEY=...` line in `<repo>/.env` with your real key, then
> tell the agent "bitdeer key is in place". The agent re-runs
> `./scripts/setup.sh --set-default` and `./scripts/verify.sh` to activate it.

## Step 4 — Configure the Bitdeer provider + pi defaults

```bash
./scripts/setup.sh --set-default
```

This performs, with timestamped backups and mode 600 on the key file:

- **`~/.pi/agent/models.json`** — merges the `bitdeer` provider:
  - `baseUrl: https://api-inference.bitdeer.ai/v1`, `api: openai-completions`,
    `apiKey` from `.env`
  - models: `zai-org/GLM-5.3` (reasoning + `reasoning_effort` support),
    `zai-org/GLM-5.3-Flash`, `moonshotai/Kimi-K3` (1M context),
    `deepseek-ai/DeepSeek-V4-Flash`, `deepseek-ai/DeepSeek-V4.1-Flash`,
    `Qwen/Qwen3.8-27B`
- **`~/.pi/agent/settings.json`** (because of `--set-default`) — sets
  `defaultProvider: "bitdeer"` and `defaultModel: "zai-org/GLM-5.3"` so plain `pi`
  starts on GLM-5.3. Existing settings are preserved.

If the placeholder key was detected, the script warns and still writes the config —
the structure is complete and only the key needs to be filled in later (Flow B).

## Step 5 — Confirm the models are registered

```bash
pi --list-models | grep -i bitdeer
```

Expected: six `bitdeer` rows including `zai-org/GLM-5.3`. `models.json` reloads
whenever `/model` is opened — no restart needed.

## Step 6 — Verify end to end

```bash
./scripts/verify.sh
```

Checks the key against `GET /v1/models`, confirms GLM-5.3 is in the live catalog,
and runs a tiny test completion. Then the full-stack smoke test through pi itself:

```bash
pi --no-session -p --model bitdeer/zai-org/GLM-5.3 "Reply with exactly: OK"
```

Expected output: `OK` (exit 0). GLM-5.3 thinks briefly before answering — that is
normal and the reasoning tokens are billed.

Finally, report to the user: what was installed and configured, where the key
lives, and how to start:

```bash
pi                                              # starts on GLM-5.3 (default)
pi --model bitdeer/zai-org/GLM-5.3 --thinking high   # explicit model + thinking
```

In-session: `/model` switches models, `/thinking` changes the thinking level.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `EACCES` installing pi globally | Use nvm (Step 1) or `curl -fsSL https://pi.dev/install.sh \| sh` |
| `node: command not found` / old Node | Install Node 22 via nvm (Step 1); pi requires ≥ 22.19 |
| verify.sh: "still contains the placeholder" | Real key not in `.env` yet — Flow B finish step (Step 3) |
| `401` / invalid API key | Key wrong or revoked — create a new key at cloud.bitdeer.ai, update `.env`, re-run `./scripts/setup.sh --set-default` |
| Models missing from `/model` or `--list-models` | Typo in a model `id`; run `./scripts/verify.sh` to list live ids from the endpoint |
| `invalid request` errors | Bitdeer rejects z.ai-style `thinking: {...}` params; it accepts `reasoning_effort` — keep `compat.supportsReasoningEffort: true`, never set `thinkingFormat: "zai"` |
| pi smoke test hangs/fails but verify.sh passes | Check `pi --version`, then re-run with `--verbose`; confirm models.json apiKey is the real key, not the placeholder |

See [references/bitdeer-api.md](references/bitdeer-api.md) for the endpoint
reference, the verified request/response behavior matrix, the full model catalog,
and pi configuration details.
