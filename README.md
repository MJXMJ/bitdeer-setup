# bitdeer-setup

An [Agent Skills](https://agentskills.io) runbook that sets up the **pi coding
agent** with **`zai-org/GLM-5.3`** from [Bitdeer AI](https://cloud.bitdeer.ai)
— end to end, on a fresh machine, executed entirely by an AI agent
(Claude Code, pi, or any other). The user does nothing hands-on except supply
the Bitdeer API key when asked.

This repository **is** the skill: a `SKILL.md` runbook, helper scripts, and an
API reference.

## What the Agent Does (end to end)

1. **Preflight** — checks/installs Node.js ≥ 22.19, npm, curl, jq
2. **Installs pi** — `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`
3. **API key** — asks you for the key, or sets up a placeholder in `.env` (gitignored) to fill in later
4. **Configures the provider** — merges `bitdeer` (GLM-5.3 + 5 more models) into `~/.pi/agent/models.json`
5. **Sets startup defaults** — plain `pi` starts on `zai-org/GLM-5.3`
6. **Verifies live** — auth check, model catalog, test completion, and a `pi -p` smoke test

## Usage

On the target machine, clone the repo and point your agent at it:

```bash
git clone https://github.com/MJXMJ/bitdeer-setup.git ~/bitdeer-setup
```

- **Claude Code:** clone into `~/.claude/skills/bitdeer-setup` for auto-discovery,
  or open the repo and say *"Execute the skill in SKILL.md"*.
- **pi:** clone into `~/.pi/agent/skills/bitdeer-setup`, then run `/skill:bitdeer-setup`.

The agent follows `SKILL.md` step by step. If you don't have the API key yet,
it completes everything with a placeholder and tells you exactly how to finish:
paste the key into `.env`, then tell the agent *"bitdeer key is in place"*.

## What's Included

| Path | Purpose |
|---|---|
| `SKILL.md` | The agent runbook: install → key → configure → verify |
| `scripts/setup.sh` | Merges the `bitdeer` provider into `~/.pi/agent/models.json`; `--set-default` also sets GLM-5.3 as pi's startup model (backs up first) |
| `scripts/verify.sh` | 4-stage verification: auth, catalog, test completion, pi smoke test |
| `references/bitdeer-api.md` | Endpoint reference, verified request/response behavior, model catalog, pi config details |
| `.env.example` | Template for the API key (real `.env` is gitignored) |

## Security

The API key is **never** committed: `.env` is gitignored, and `setup.sh` only
writes the key to `~/.pi/agent/models.json` (mode `600`) on your own machine.
If a key is ever exposed, rotate it in the Bitdeer console.
