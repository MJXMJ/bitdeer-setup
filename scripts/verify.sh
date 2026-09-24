#!/usr/bin/env bash
#
# verify.sh — end-to-end verification of the Bitdeer AI + pi setup.
#
#   1/4  Auth check against GET /v1/models
#   2/4  Confirm zai-org/GLM-5.3 is in the live catalog
#   3/4  Tiny test completion on GLM-5.3
#   4/4  Full-stack smoke test through pi itself (skipped if pi is not installed)
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
PLACEHOLDER="your-bitdeer-api-key"

command -v jq  >/dev/null || { echo "error: jq is required (brew install jq / apt install jq)" >&2; exit 1; }
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
if [[ "$KEY" == "$PLACEHOLDER" ]]; then
  echo "error: $SKILL_ROOT/.env still contains the PLACEHOLDER key."
  echo "       Replace the BITDEER_API_KEY line with your real key (cloud.bitdeer.ai → API Keys),"
  echo "       then re-run ./scripts/setup.sh --set-default and this script." >&2
  exit 1
fi

echo "== 1/4 Auth + model catalog =="
if ! CATALOG="$(curl -sS -f -m 30 "$ENDPOINT/models" -H "Authorization: Bearer $KEY" 2>/dev/null)"; then
  echo "error: GET $ENDPOINT/models failed — check your API key and network." >&2
  exit 1
fi
echo "Authenticated. Models available:"
echo "$CATALOG" | jq -r '.data[].id' | sed 's/^/  - /'

echo
echo "== 2/4 Model check: $MODEL =="
if ! echo "$CATALOG" | jq -e --arg m "$MODEL" '[.data[].id] | index($m)' >/dev/null; then
  echo "error: '$MODEL' is not in the live catalog (list above)." >&2
  exit 1
fi
echo "✓ '$MODEL' is available"

echo
echo "== 3/4 Test completion on $MODEL =="
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
echo "== 4/4 pi smoke test =="
if command -v pi >/dev/null 2>&1; then
  if PI_OUT="$(pi --no-session -p --model "bitdeer/$MODEL" "Reply with exactly: OK" 2>/dev/null)" && [[ "$PI_OUT" == *"OK"* ]]; then
    echo "✓ pi answered via bitdeer/$MODEL: OK"
  else
    echo "error: pi smoke test failed. pi is installed but the request through it did not succeed." >&2
    echo "       Check that ~/.pi/agent/models.json has the real key (not the placeholder):" >&2
    echo "         jq -r '.providers.bitdeer.apiKey' ~/.pi/agent/models.json" >&2
    exit 1
  fi
else
  echo "SKIP: pi is not installed (or not on PATH) — API checks above passed."
  echo "      Install pi, then re-run: npm install -g --ignore-scripts @earendil-works/pi-coding-agent"
fi

echo
echo "All checks passed. Start pi with:"
echo "  pi                                        # starts on the default model (set via setup.sh --set-default)"
echo "  pi --model bitdeer/$MODEL"
