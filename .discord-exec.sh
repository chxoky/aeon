#!/bin/bash
set -e

# Discord Trader Monitor execution script
# Process Discord message event from Cloudflare Worker

B64_EVENT='eyJpZCI6IjE1Mjk4NTY4MDgxNzEwNzc2MzIiLCJjaGFubmVsX2lkIjoiMTI0NzkyNzc4NjY4MTc5NDYwMSIsInVzZXJuYW1lIjoiY3J5cHRvX2NoYXNlIiwiY29udGVudCI6IkkgbWVhbiB3aHkgZG8geW91IGd1eXMgdGhpbmsgZXZlcnkgc2luZ2xlIGNyeXB0byBleGNoYW5nZSBzdGFydGVkIGxpc3Rpbmcgc3RvY2tzIGxvbCIsImNyZWF0ZWRfYXQiOiIyMDI2LTA3LTIzVDE0OjI0OjQ2LjQzMzAwMCswMDowMCIsImlzX3JlcGx5IjpmYWxzZSwicmVmZXJlbmNlZF9tZXNzYWdlIjpudWxsLCJhdHRhY2htZW50cyI6W10sImZhc3RfcGF0aF9hbGVydGVkIjpmYWxzZX0='

# Step 1: Decode the event
echo "=== Step 1: Decode Event ==="
EVENT_JSON=$(echo "$B64_EVENT" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: Failed to decode"
  exit 1
fi

echo "$EVENT_JSON" | jq . 2>/dev/null || {
  echo "DISCORD_TRADER_BAD_EVENT: Invalid JSON"
  exit 1
}

# Extract fields
ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply // false')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')

echo ""
echo "=== Event Details ==="
echo "Message ID: $ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"

# Step 2: Check if already seen
echo ""
echo "=== Step 2: Dedup Check ==="
mkdir -p memory
touch memory/discord-trader-seen.txt

if grep -q "^$ID$" memory/discord-trader-seen.txt 2>/dev/null; then
  echo "Message already seen, skipping alert"
  exit 0
else
  echo "$ID" >> memory/discord-trader-seen.txt
  echo "New message, proceeding"
fi

# Step 3: Classification
echo ""
echo "=== Step 3: Message Classification ==="

# Check for test messages (HR-1)
if echo "$CONTENT" | grep -iE "test|testing" > /dev/null; then
  echo "Classification: SKIP (test message)"

  # Log only
  mkdir -p memory/logs
  LOG_DATE=$(date +%Y-%m-%d)
  cat >> "memory/logs/${LOG_DATE}.md" << EOF

### discord-trader-monitor (real-time event)
- trader: $USERNAME
- channel: $CHANNEL_ID (supporting)
- message_id: $ID
- classification: skip
- ticker(s): none
- alerted: no
- notes: test message ignored

EOF
  exit 0
fi

# Check for financial content vs banter
echo "Content analysis:"
echo "  - Mentions exchange/stocks: YES (crypto exchange + stocks)"
echo "  - Is a trade signal: NO (rhetorical question/banter)"
echo "  - Classification: BANTER/NON-FINANCIAL"

# Step 4: Resolve trader + channel
echo ""
echo "=== Step 4: Resolve Trader + Channel ==="
echo "Trader handle: $USERNAME"
echo "Channel ID: $CHANNEL_ID (Crypto_Chase supporting channel)"

# Step 5: Alert decision
echo ""
echo "=== Step 5: Alert Decision ==="
echo "→ Non-financial content (rhetorical banter about exchanges listing stocks)"
echo "→ Skip alerting, log only"

# Log the event
mkdir -p memory/logs
LOG_DATE=$(date +%Y-%m-%d)
cat >> "memory/logs/${LOG_DATE}.md" << EOF

### discord-trader-monitor (real-time event)
- trader: $USERNAME
- channel: $CHANNEL_ID (supporting)
- message_id: $ID
- classification: skip
- ticker(s): none
- alerted: no
- notes: banter/non-financial — crypto exchange stock listing comment

EOF

echo ""
echo "=== Summary ==="
echo "Status: SKIPPED (non-financial banter)"
echo "Alert sent: NO"
echo "Logged: YES"
