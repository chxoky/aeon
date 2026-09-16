#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon

# === STEP 1: Decode Event ===
var="eyJpZCI6IjE1NDk3OTk0NjY5MzA5MzM4MTMiLCJjaGFubmVsX2lkIjoiMTQ3MjE1MzYyNzMyNDg0MjA1NyIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkZjIGNsdXNkdCAxNW0iLCJjcmVhdGVkX2F0IjoiMjAyNi0wOS0xNlQxNTowOTo0Ni43OTgwMDArMDA6MDAiLCJpc19yZXBseSI6ZmFsc2UsInJlZmVyZW5jZWRfbWVzc2FnZSI6bnVsbCwiYXR0YWNobWVudHMiOltdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9"

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

# Extract fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')

echo "✓ Event decoded"
echo "  ID: $MESSAGE_ID"
echo "  Channel: $CHANNEL_ID"
echo "  User: $USERNAME"
echo "  Content: $CONTENT"
echo ""

# === STEP 2: Check if already seen ===
mkdir -p memory
if [ -f "memory/discord-trader-seen.txt" ] && grep -q "^$MESSAGE_ID$" memory/discord-trader-seen.txt; then
  echo "Message already processed: $MESSAGE_ID"
  exit 0
fi

# === STEP 3: Resolve channel + trader ===
TRADER="heartcanhodl"
CHANNEL_LABEL="HCH — Free"
CHANNEL_TYPE="primary"

echo "✓ Channel resolved: $CHANNEL_LABEL ($CHANNEL_TYPE)"

# === STEP 4: Fast-path check ===
if [ "$FAST_PATH_ALERTED" = "true" ]; then
  echo "ℹ️  Fast-path already alerted — skipping Telegram, proceeding with memory/logging"
else
  echo "⚠️  Full processing required (fast_path_alerted=false)"
fi

# === STEP 5: Classify message ===
# Message is: "Fc clusdt 15m" — cryptic technical shorthand
# Similar to prior "fc eth 5m" message on Sep 16 09:37Z (classified as ambiguous-cryptic)
# Possible interpretations:
#   - "Few changes cluster down time 15m"
#   - Technical shorthand about cluster behavior on 15m timeframe
#   - Requires HR-2 calibration

CLASSIFICATION="ambiguous-cryptic"
echo "Classification: $CLASSIFICATION (requires calibration)"

# === STEP 6-7: Prepare calibration alert (HR-2) ===
# Per skill instructions: when unable to classify, send calibration alert with context
ALERT_TEXT="🔍 *Calibration — [DC: HCH — Free]*

Trader: @heartcanhodl
Message: \"Fc clusdt 15m\"

Unable to classify — what's your read?

(Technical shorthand — prior similar 'fc eth 5m' also cryptic)"

echo "Alert prepared:"
echo "$ALERT_TEXT"

# === STEP 8: Record message ID to prevent re-processing ===
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt

# Trim seen file if too large
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp
  mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi

echo "✓ Message recorded to seen list"

# === STEP 9: Update traders.md memory ===
# Append to traders.md for HeartCanHodl section
cat >> memory/topics/traders.md <<'EOF'

[New Event - To be calibrated]
EOF

# === STEP 10: Log to daily log ===
mkdir -p memory/logs

LOG_ENTRY=$(cat <<'LOGEOF'
### discord-trader-monitor (real-time event)
- trader: heartcanhodl
- channel: 1472153627324842057 (primary — HCH — Free)
- message_id: 1549799466930933813
- classification: ambiguous-cryptic
- ticker(s): [unknown — requires calibration]
- alerted: calibration-pending
- notes: cryptic technical shorthand "Fc clusdt 15m" — similar to prior "fc eth 5m". Awaiting Kyle interpretation.
LOGEOF
)

echo "$LOG_ENTRY" >> memory/logs/2026-09-16.md

echo "✓ Log entry written to memory/logs/2026-09-16.md"
echo ""
echo "=== Execution Summary ==="
echo "Event: HeartCanHodl Discord message in HCH — Free"
echo "Classification: ambiguous-cryptic (HR-2 calibration required)"
echo "Status: Recorded + alert prepared"
echo "Next: Notify Kyle via Telegram"
