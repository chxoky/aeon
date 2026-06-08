#!/usr/bin/env bash
# prefetch-chart-request.sh
# Runs BEFORE Claude starts. Polls Telegram getUpdates for chart command messages,
# saves matching requests to .xai-cache/chart-request-messages.json, and advances offset.
# Called by AEON's workflow: ./scripts/prefetch-*.sh <skill_name> <var>
# Only activates for the chart-request skill.

set -euo pipefail

SKILL="${1:-}"
[ "$SKILL" = "chart-request" ] || exit 0

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  echo "prefetch-chart-request: TELEGRAM_BOT_TOKEN not set, skipping"
  exit 0
fi

mkdir -p .xai-cache .pending-chart-request

OFFSET_FILE=".xai-cache/chart-request-offset.txt"
MESSAGES_FILE=".xai-cache/chart-request-messages.json"
OFFSET=0
if [ -f "$OFFSET_FILE" ]; then
  OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)
fi

echo "prefetch-chart-request: polling getUpdates (offset=$OFFSET)..."

# Poll Telegram — timeout=0 for non-blocking
TG_RESP=$(curl -sf --max-time 15 \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=0&limit=100" 2>/dev/null) || {
  echo "prefetch-chart-request: curl failed (sandbox?), writing empty cache"
  echo "[]" > "$MESSAGES_FILE"
  exit 0
}

# Write raw response to a temp file so Python can read it without quoting issues
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

# Pattern: chart $TICKER [TIMEFRAME] [INDICATOR]
chart_re = re.compile(
    r"^\s*chart\s+\$?([A-Za-z0-9]+)(?:\s+([A-Za-z0-9]+))?(?:\s+([A-Za-z0-9]+))?\s*$",
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

    ticker   = m.group(1).upper()
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

# Advance offset so we don't reprocess these updates
if max_update_id is not None:
    with open(offset_path, "w") as f:
        f.write(str(max_update_id + 1))

print(f"prefetch-chart-request: {len(updates)} updates, {len(chart_messages)} chart request(s)")
PYEOF

echo "prefetch-chart-request: done"
