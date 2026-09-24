#!/usr/bin/env bash
#
# setup.sh — configure the Bitdeer AI provider (zai-org/GLM-5.3) for the pi coding agent.
#
# Merges the provider config into ~/.pi/agent/models.json.
# The API key is read from (in order): $BITDEER_API_KEY, .env next to this
# script, or an interactive prompt. The key is only ever written to
# ~/.pi/agent/models.json (outside any git repo) — never into this repository.
#
# Usage:
#   ./scripts/setup.sh                 # store the literal key in models.json (default)
#   ./scripts/setup.sh --use-env-var   # store "$BITDEER_API_KEY" reference instead
#   PI_MODELS_JSON=/tmp/test.json ./scripts/setup.sh   # dry-run to another file
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_JSON="${PI_MODELS_JSON:-$HOME/.pi/agent/models.json}"
USE_ENV_VAR=0

for arg in "$@"; do
  case "$arg" in
    --use-env-var) USE_ENV_VAR=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown option: $arg (see --help)" >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null || { echo "error: jq is required (brew install jq)" >&2; exit 1; }

# --- Locate the API key ------------------------------------------------------
if [[ -f "$SKILL_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SKILL_ROOT/.env"
  set +a
fi

API_KEY="${BITDEER_API_KEY:-}"
if [[ -z "$API_KEY" && $USE_ENV_VAR -eq 0 ]]; then
  read -rsp "Bitdeer API key (input hidden): " API_KEY
  echo
fi
if [[ -z "$API_KEY" ]]; then
  echo "error: no API key found. Set BITDEER_API_KEY, put it in $SKILL_ROOT/.env, or run without --use-env-var to be prompted." >&2
  exit 1
fi

# Representation of the key written into models.json
if [[ $USE_ENV_VAR -eq 1 ]]; then
  KEY_VALUE='$BITDEER_API_KEY'   # pi resolves this env var at request time
else
  KEY_VALUE="$API_KEY"
fi

# --- Provider config ---------------------------------------------------------
# Verified against https://api-inference.bitdeer.ai/v1 (see references/bitdeer-api.md):
#  - OpenAI Chat Completions compatible, Bearer auth, streaming supported
#  - GLM-5.3 reasons by default (returns reasoning_content) and accepts
#    reasoning_effort -> enable reasoning + supportsReasoningEffort
#  - The z.ai-style "thinking" parameter is NOT accepted: never set thinkingFormat "zai"
PROVIDER="$(jq -n --arg key "$KEY_VALUE" '{
  baseUrl: "https://api-inference.bitdeer.ai/v1",
  api: "openai-completions",
  apiKey: $key,
  models: [
    {
      id: "zai-org/GLM-5.3",
      name: "GLM-5.3 (Bitdeer)",
      reasoning: true,
      compat: { supportsReasoningEffort: true }
    },
    { id: "zai-org/GLM-5.3-Flash" },
    { id: "moonshotai/Kimi-K3", contextWindow: 1048576 },
    { id: "deepseek-ai/DeepSeek-V4-Flash" },
    { id: "deepseek-ai/DeepSeek-V4.1-Flash" },
    { id: "Qwen/Qwen3.8-27B" }
  ]
}')"

# --- Merge into models.json --------------------------------------------------
mkdir -p "$(dirname "$MODELS_JSON")"
if [[ ! -f "$MODELS_JSON" ]]; then
  echo '{"providers": {}}' > "$MODELS_JSON"
else
  BACKUP="$MODELS_JSON.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$MODELS_JSON" "$BACKUP"
  echo "Backup written: $BACKUP"
fi

jq --argjson provider "$PROVIDER" \
  '.providers = (.providers // {}) | .providers.bitdeer = $provider' \
  "$MODELS_JSON" > "$MODELS_JSON.tmp" && mv "$MODELS_JSON.tmp" "$MODELS_JSON"
chmod 600 "$MODELS_JSON"

echo
echo "✓ Bitdeer provider written to $MODELS_JSON"
echo "  Endpoint: https://api-inference.bitdeer.ai/v1"
echo "  Models:   zai-org/GLM-5.3 (reasoning), GLM-5.3-Flash, Kimi-K3,"
echo "            DeepSeek-V4-Flash, DeepSeek-V4.1-Flash, Qwen3.8-27B"
if [[ $USE_ENV_VAR -eq 1 ]]; then
  echo
  echo "NOTE: models.json references \$BITDEER_API_KEY. Export it in your shell profile:"
  echo "  echo 'export BITDEER_API_KEY=your-key' >> ~/.zshrc"
fi
echo
echo "Next steps:"
echo "  1. ./scripts/verify.sh                    # test the key and endpoint"
echo "  2. pi --list-models | grep -i bitdeer     # confirm the models loaded"
echo "  3. pi --model bitdeer/zai-org/GLM-5.3     # start a session on GLM-5.3"
