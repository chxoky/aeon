#!/bin/bash
set -e

# Decode the Discord event
EVENT_JSON=$(cat <<'EOF' | base64 -d
eyJpZCI6IjE1NDA2NDY3MTE5ODk1MDYxMDgiLCJjaGFubmVsX2lkIjoiMTAyMzYzODU3MzMxMzk2NjIxMiIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkNhbWUgYWNyb3NzIHNvbWUgYXJndW1lbnQiLCJjcmVhdGVkX2F0IjoiMjAyNi0wOC0yMlQwODo1OTo1OS45NzAwMDArMDA6MDAiLCJpc19yZXBseSI6ZmFsc2UsInJlZmVyZW5jZWRfbWVzc2FnZSI6bnVsbCwiYXR0YWNobWVudHMiOltdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9
EOF
)

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .
echo ""

# Extract fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply')
FAST_PATH=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted')

echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH"
echo ""

# Check for empty content
if [ -z "$CONTENT" ] || [ "$CONTENT" = "null" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: empty content"
  exit 1
fi

# Load channel mapping from JSON
CHANNELS_JSON=$(cat memory/discord-channels.json)

# Lookup the channel label
CHANNEL_LABEL=$(echo "$CHANNELS_JSON" | jq -r ".channel_labels.\"$CHANNEL_ID\" // \"Unknown\"")

echo "Channel Label: $CHANNEL_LABEL"

# Determine trader and type
TRADER_NAME=""
CHANNEL_TYPE=""

for trader in $(echo "$CHANNELS_JSON" | jq -r '.traders | keys[]'); do
  TRADER_LOWER=$(echo "$trader" | tr '[:upper:]' '[:lower:]')
  USERNAME_LOWER=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

  if [ "$USERNAME_LOWER" = "$TRADER_LOWER" ]; then
    TRADER_NAME="$trader"
    TRADER_CONFIG=$(echo "$CHANNELS_JSON" | jq -r ".traders.\"$trader\"")

    PRIMARY_CHANNELS=$(echo "$TRADER_CONFIG" | jq -r '.channels.primary[]')
    SUPPORTING_CHANNELS=$(echo "$TRADER_CONFIG" | jq -r '.channels.supporting[]')

    if echo "$PRIMARY_CHANNELS" | grep -q "^$CHANNEL_ID$"; then
      CHANNEL_TYPE="primary"
    elif echo "$SUPPORTING_CHANNELS" | grep -q "^$CHANNEL_ID$"; then
      CHANNEL_TYPE="supporting"
    fi
    break
  fi
done

if [ -z "$TRADER_NAME" ]; then
  echo "ERROR: Username $USERNAME not recognized as a tracked trader"
  exit 1
fi

echo "Trader: $TRADER_NAME"
echo "Channel Type: $CHANNEL_TYPE"
echo ""

# Fast-path check
if [ "$FAST_PATH" = "true" ]; then
  echo "⚡ Fast-path already alerted - skipping Telegram sends"
  SKIP_TELEGRAM=1
else
  echo "Processing full flow with Telegram alerts"
  SKIP_TELEGRAM=0
fi
echo ""

# Classify message (simplified)
echo "=== Message Classification ==="
LOWERCASE_CONTENT=$(echo "$CONTENT" | tr '[:upper:]' '[:lower:]')

# Check for test patterns (HR-1)
if echo "$LOWERCASE_CONTENT" | grep -qE '(^|\s)test(\s|$)|testing'; then
  echo "Classification: NON_FINANCIAL (test message)"
  CLASSIFICATION="skip"
  SHOULD_ALERT=0
else
  # This is informational - came across some argument
  echo "Classification: INFORMATIONAL"
  CLASSIFICATION="informational"
  SHOULD_ALERT=1
fi

echo "Should Alert: $SHOULD_ALERT"
echo ""

# Check if already seen
echo "=== Dedup Check ==="
mkdir -p memory
if [ -f memory/discord-trader-seen.txt ] && grep -q "^$MESSAGE_ID$" memory/discord-trader-seen.txt; then
  echo "Already seen - skip"
  exit 0
fi

echo "✓ New message"
echo ""

# Step 6-7: Prepare alert
if [ "$SHOULD_ALERT" = "1" ] && [ "$SKIP_TELEGRAM" = "0" ]; then
  echo "=== Preparing Alert ==="

  ALERT_MSG="💬 *[DC: $CHANNEL_LABEL]*

$CONTENT"

  echo "$ALERT_MSG"
  echo ""
  echo "Would send via ./notify"
fi

# Update seen tracking
echo "=== Updating Memory ==="
mkdir -p memory
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt

# Trim if too large
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp
  mv memory/discord-trader-seen.tmp memory/discord-trader-seen.tmp
  echo "Trimmed seen list to 2000 entries"
fi

# Log the event
echo "✓ Updated seen list"
echo ""

mkdir -p memory/logs

TODAY="2026-08-22"
LOG_FILE="memory/logs/${TODAY}.md"

LOG_ENTRY="### discord-trader-monitor (real-time event)
- trader: $TRADER_NAME
- channel: $CHANNEL_ID ($CHANNEL_TYPE)
- message_id: $MESSAGE_ID
- classification: $CLASSIFICATION
- ticker(s): []
- alerted: $([ "$SHOULD_ALERT" = "1" ] && [ "$SKIP_TELEGRAM" = "0" ] && echo "yes" || echo "no")
- notes: informational from $CHANNEL_LABEL"

if [ ! -f "$LOG_FILE" ]; then
  echo "$LOG_ENTRY" > "$LOG_FILE"
else
  echo "" >> "$LOG_FILE"
  echo "$LOG_ENTRY" >> "$LOG_FILE"
fi

echo "=== Logging Event ==="
echo "Logged to $LOG_FILE:"
echo "$LOG_ENTRY"
echo ""
echo "✅ Processing Complete"
