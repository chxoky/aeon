#!/usr/bin/env bash
# prefetch-chart-request.sh
# Runs BEFORE Claude starts. Two modes:
#   1. VAR is set: parse chart command directly from VAR (dispatched via messages.yml routing)
#   2. VAR is empty: poll Telegram getUpdates for chart commands (scheduled runs)
# Saves parsed requests to .xai-cache/chart-request-messages.json.

set -euo pipefail

SKILL="${1:-}"
VAR="${2:-}"
[ "$SKILL" = "chart-request" ] || exit 0

mkdir -p .xai-cache .pending-chart-request

MESSAGES_FILE=".xai-cache/chart-request-messages.json"
OFFSET_FILE=".xai-cache/chart-request-offset.txt"

# Pattern: chart $TICKER [TIMEFRAME] [INDICATOR]
parse_chart_command() {
  local text="$1"
  python3 - "$text" <<'PYEOF'
import sys, re, json

text = sys.argv[1].strip()
chart_re = re.compile(
    r"^chart\s+\$?([A-Za-z0-9]+)(?:\s+([A-Za-z0-9]+))?(?:\s+([A-Za-z0-9]+))?\s*$",
    re.IGNORECASE
)
m = chart_re.match(text)
if not m:
    print("[]")
    sys.exit(0)

ticker    = m.group(1).upper()
timeframe = (m.group(2) or "1D").upper()
indicator = (m.group(3) or "EMA50").upper()

print(json.dumps([{
    "message_id": None,
    "chat_id": None,
    "ticker": ticker,
    "timeframe": timeframe,
    "indicator": indicator,
    "requested_by": "user",
    "original_text": text,
}]))
PYEOF
}

# ── Mode 1: VAR-based (routed from messages.yml) ─────────────────────────────
if [ -n "$VAR" ]; then
  echo "prefetch-chart-request: var-mode, parsing: $VAR"

  PARSED=$(parse_chart_command "$VAR")
  COUNT=$(echo "$PARSED" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

  if [ "$COUNT" -eq 0 ]; then
    echo "prefetch-chart-request: could not parse chart command from var"
    echo "[]" > "$MESSAGES_FILE"
    exit 0
  fi

  # Inject chat_id from env if available (so postprocess knows where to send)
  CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  if [ -n "$CHAT_ID" ]; then
    PARSED=$(echo "$PARSED" | python3 -c "
import json, sys
msgs = json.load(sys.stdin)
for m in msgs:
    m['chat_id'] = int('$CHAT_ID')
print(json.dumps(msgs))
" 2>/dev/null || echo "$PARSED")
  fi

  echo "$PARSED" > "$MESSAGES_FILE"
  echo "prefetch-chart-request: wrote 1 chart request from var"
  exit 0
fi

# ── Mode 2: Telegram polling (scheduled runs) ─────────────────────────────────
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  echo "prefetch-chart-request: TELEGRAM_BOT_TOKEN not set, skipping"
  echo "[]" > "$MESSAGES_FILE"
  exit 0
fi

OFFSET=0
if [ -f "$OFFSET_FILE" ]; then
  OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)
fi

echo "prefetch-chart-request: polling getUpdates (offset=$OFFSET)..."

TG_RESP=$(curl -sf --max-time 15 \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=0&limit=100" 2>/dev/null) || {
  echo "prefetch-chart-request: curl failed (sandbox?), writing empty cache"
  echo "[]" > "$MESSAGES_FILE"
  exit 0
}

TMP_RESP=$(mktemp)
echo "$TG_RESP" > "$TMP_RESP"
trap 'rm -f "$TMP_RESP"' EXIT

python3 - "$TMP_RESP" "$OFFSET_FILE" "$MESSAGES_FILE" <<'PYEOF'
import json, sys, re

resp_path, offset_path, messages_path = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(resp_path) as f:
        data = json.load(f)
except Exception as e:
    print(f"prefetch-chart-request: parse error: {e}", flush=True)
    with open(messages_path, "w") as f:
        json.dump([], f)
    sys.exit(0)

if not data.get("ok"):
    desc = data.get("description", "unknown error")
    print(f"prefetch-chart-request: Telegram API error: {desc}", flush=True)
    with open(messages_path, "w") as f:
        json.dump([], f)
    sys.exit(0)

updates = data.get("result", [])

chart_re = re.compile(
    r"^chart\s+\$?([A-Za-z0-9]+)(?:\s+([A-Za-z0-9]+))?(?:\s+([A-Za-z0-9]+))?\s*$",
    re.IGNORECASE
)

chart_messages = []
max_update_id = None

for update in updates:
    update_id = update.get("update_id", 0)
    if max_update_id is None or update_id > max_update_id:
        max_update_id = update_id

    msg = update.get("message") or update.get("channel_post")
    if not msg:
        continue

    text = msg.get("text", "").strip()
    if not text:
        continue

    m = chart_re.match(text)
    if not m:
        continue

    ticker    = m.group(1).upper()
    timeframe = (m.group(2) or "1D").upper()
    indicator = (m.group(3) or "EMA50").upper()

    chat      = msg.get("chat", {})
    from_user = msg.get("from", {})

    chart_messages.append({
        "message_id":   msg.get("message_id"),
        "chat_id":      chat.get("id"),
        "ticker":       ticker,
        "timeframe":    timeframe,
        "indicator":    indicator,
        "requested_by": from_user.get("username") or from_user.get("first_name") or "unknown",
        "original_text": text,
    })

with open(messages_path, "w") as f:
    json.dump(chart_messages, f, indent=2)

if max_update_id is not None:
    with open(offset_path, "w") as f:
        f.write(str(max_update_id + 1))

print(f"prefetch-chart-request: {len(updates)} updates, {len(chart_messages)} chart request(s)")
PYEOF

echo "prefetch-chart-request: done"
