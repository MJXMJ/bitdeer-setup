# bitdeer-setup

A [pi](https://github.com/earendil-works/pi-coding-agent) skill that sets up
**`zai-org/GLM-5.3`** (and other models) from [Bitdeer AI](https://cloud.bitdeer.ai)
as a model provider, via Bitdeer's OpenAI-compatible inference API at
`https://api-inference.bitdeer.ai/v1`.

This repository **is** the skill — it contains a `SKILL.md`, helper scripts, and
an API reference.

## Quick Start

```bash
git clone https://github.com/MJXMJ/bitdeer-setup.git
cd bitdeer-setup
cp .env.example .env   # paste your Bitdeer API key (https://cloud.bitdeer.ai → API Keys)
./scripts/setup.sh     # merges the bitdeer provider into ~/.pi/agent/models.json
./scripts/verify.sh    # tests the key, lists models, runs a tiny GLM-5.3 completion
pi --model bitdeer/zai-org/GLM-5.3
```

## What's Included

| Path | Purpose |
|---|---|
| `SKILL.md` | The skill itself: setup instructions, usage, troubleshooting |
| `scripts/setup.sh` | Merges the `bitdeer` provider into `~/.pi/agent/models.json` (backs up first) |
| `scripts/verify.sh` | Auth check, live model catalog, GLM-5.3 test completion |
| `references/bitdeer-api.md` | Endpoint reference, verified request/response behavior, model catalog |
| `.env.example` | Template for the API key (real `.env` is gitignored) |

## Using the Skill in pi

Clone (or symlink) this repo into a skill location, e.g.:

```bash
git clone https://github.com/MJXMJ/bitdeer-setup.git ~/.pi/agent/skills/bitdeer-setup
```

Then ask pi to set up Bitdeer/GLM-5.3, or run `/skill:bitdeer-setup` directly.

## Security

The API key is **never** committed: `.env` is gitignored, and `setup.sh` only
writes the key to `~/.pi/agent/models.json` (mode `600`) on your own machine.
If a key is ever exposed, rotate it in the Bitdeer console.
