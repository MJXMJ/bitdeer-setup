#!/usr/bin/env bash
#
# verify.sh — check the Bitdeer AI setup: auth, model catalog, and a tiny
# GLM-5.3 test completion.
#
# Key resolution order: $BITDEER_API_KEY, .env next to this script, then the
# apiKey stored in ~/.pi/agent/models.json by setup.sh.
#
# Usage:
#   ./scripts/verify.sh
#   BITDEER_MODEL=zai-org/GLM-5.3-Flash ./scripts/verify.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
ENDPOINT="https://api-inference.bitdeer.ai/v1"
MODEL="${BITDEER_MODEL:-zai-org/GLM-5.3}"

command -v jq  >/dev/null || { echo "error: jq is required (brew install jq)" >&2; exit 1; }
command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }

if [[ -f "$SKILL_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SKILL_ROOT/.env"
  set +a
fi

KEY="${BITDEER_API_KEY:-}"
if [[ -z "$KEY" && -f "$HOME/.pi/agent/models.json" ]]; then
  KEY="$(jq -r '.providers.bitdeer.apiKey // empty' "$HOME/.pi/agent/models.json")"
  # Resolve "$ENV_VAR" / "${ENV_VAR}" references stored by setup.sh --use-env-var
  if [[ "$KEY" == '$'* ]]; then
    VAR="${KEY:1}"
    VAR="${VAR#\{}"
    VAR="${VAR%\}}"
    KEY="${!VAR:-}"
  fi
fi
if [[ -z "$KEY" ]]; then
  echo "error: no API key. Set BITDEER_API_KEY, put it in $SKILL_ROOT/.env, or run setup.sh first." >&2
  exit 1
fi

echo "== 1/3 Auth + model catalog =="
if ! CATALOG="$(curl -sS -f -m 30 "$ENDPOINT/models" -H "Authorization: Bearer $KEY" 2>/dev/null)"; then
  echo "error: GET $ENDPOINT/models failed — check your API key and network." >&2
  exit 1
fi
echo "Authenticated. Models available:"
echo "$CATALOG" | jq -r '.data[].id' | sed 's/^/  - /'

echo
echo "== 2/3 Model check: $MODEL =="
if ! echo "$CATALOG" | jq -e --arg m "$MODEL" '[.data[].id] | index($m)' >/dev/null; then
  echo "error: '$MODEL' is not in the live catalog (list above)." >&2
  exit 1
fi
echo "✓ '$MODEL' is available"

echo
echo "== 3/3 Test completion on $MODEL =="
if ! RESP="$(curl -sS -f -m 120 "$ENDPOINT/chat/completions" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: OK\"}],\"max_tokens\":4000}" 2>/dev/null)"; then
  echo "error: chat completion failed — the key authenticates but the model rejected the request." >&2
  exit 1
fi
CONTENT="$(echo "$RESP" | jq -r '.choices[0].message.content')"
RTOKENS="$(echo "$RESP" | jq -r '.usage.reasoning_tokens // 0')"
echo "✓ $MODEL replied: ${CONTENT:-<empty>} (reasoning tokens: $RTOKENS)"

echo
echo "All checks passed. Start pi with:"
echo "  pi --model bitdeer/$MODEL"
