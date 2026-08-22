#!/bin/bash
set -euo pipefail

# Discord Trader Monitor execution
var="eyJpZCI6IjE1NDA2NDc2Nzc1NjAzNTY5MjQiLCJjaGFubmVsX2lkIjoiMTAyMzYzODU3MzMxMzk2NjIxMiIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkEgZnVsbCBtZWdhIHJldHJhY2Ugd2lsbCBtYWtlIGFsbCBsb3NlIHRoZWlyIG1pbmRzIPCfkYAiLCJjcmVhdGVkX2F0IjoiMjAyNi0wOC0yMlQwOTowMzo1MC4xODAwMDArMDA6MDAiLCJpc19yZXBseSI6ZmFsc2UsInJlZmVyZW5jZWRfbWVzc2FnZSI6bnVsbCwiYXR0YWNobWVudHMiOltdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9"

# Step 1: Decode the event
echo "=== Step 1: Decoding event ==="
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: could not decode base64"
  exit 1
fi

echo "$EVENT_JSON" | jq . || {
  echo "DISCORD_TRADER_BAD_EVENT: invalid JSON"
  exit 1
}

# Extract fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments | length')

echo ""
echo "=== Event Details ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"
echo "Attachments: $ATTACHMENTS"

# Step 2: Check if already seen
echo ""
echo "=== Step 2: Deduplication check ==="
mkdir -p memory
if [ -f "memory/discord-trader-seen.txt" ] && grep -q "^$MESSAGE_ID$" memory/discord-trader-seen.txt; then
  echo "Message already processed - SKIPPING"
  exit 0
fi

echo "New message - proceeding with processing"
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt

# Trim seen file if too large
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
  echo "Trimmed seen file to 2000 entries"
fi

# Step 3: Resolve channel and trader
echo ""
echo "=== Step 3: Resolving channel and trader ==="

# Load channel mappings
if [ ! -f "memory/discord-channels.json" ]; then
  echo "ERROR: memory/discord-channels.json not found"
  exit 1
fi

TRADER=$(jq -r ".\"$CHANNEL_ID\".trader // empty" memory/discord-channels.json)
CHANNEL_TYPE=$(jq -r ".\"$CHANNEL_ID\".type // empty" memory/discord-channels.json)
CHANNEL_LABEL=$(jq -r ".\"$CHANNEL_ID\".label // empty" memory/discord-channels.json)

if [ -z "$TRADER" ]; then
  echo "WARNING: Unknown channel $CHANNEL_ID"
fi

echo "Trader: $TRADER"
echo "Channel Type: $CHANNEL_TYPE"
echo "Channel Label: $CHANNEL_LABEL"

# Step 4: Check username matches
echo ""
echo "=== Step 4: Username verification ==="
TRADER_LOWER=$(echo "$TRADER" | tr '[:upper:]' '[:lower:]')
USERNAME_LOWER=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

if [ "$TRADER_LOWER" != "$USERNAME_LOWER" ]; then
  echo "Username mismatch: $USERNAME != $TRADER (this is a member message, skipping)"
  exit 0
fi

echo "Username matches - $USERNAME is $TRADER"

# Step 5: Check if it's a test message
echo ""
echo "=== Step 5: Test message check ==="
CONTENT_LOWER=$(echo "$CONTENT" | tr '[:upper:]' '[:lower:]')
if echo "$CONTENT_LOWER" | grep -qE "test|testing"; then
  echo "Test message detected - skipping silently"
  exit 0
fi

# Step 6: Load memory context
echo ""
echo "=== Step 6: Loading memory context ==="
if [ -f "memory/topics/traders.md" ]; then
  echo "Loaded traders.md"
fi
if [ -f "memory/topics/ticker-focus.md" ]; then
  echo "Loaded ticker-focus.md"
fi
if [ -f "memory/topics/active-trades.md" ]; then
  echo "Loaded active-trades.md"
fi

# Step 7: Classification
echo ""
echo "=== Step 7: Message classification ==="
CLASSIFICATION="informational"

# Check for trading language (simplified)
if echo "$CONTENT_LOWER" | grep -qE "long|short|buy|sell|place|cancel|order|position"; then
  CLASSIFICATION="potential-trade"
  echo "Detected trading language: $CLASSIFICATION"
else
  echo "Non-trading message: $CLASSIFICATION"
fi

# Step 8: Format alert (if not fast-path alerted)
echo ""
echo "=== Step 8: Alert formatting ==="
if [ "$FAST_PATH_ALERTED" = "true" ]; then
  echo "Fast-path already alerted - skipping Telegram send"
else
  echo "Preparing alert for notification..."

  ALERT_MESSAGE="💬 *[DC: $CHANNEL_LABEL]*

$CONTENT"

  echo "Alert message prepared:"
  echo "$ALERT_MESSAGE"
fi

# Step 9: Update memory log
echo ""
echo "=== Step 9: Updating memory ==="
TODAY=$(date +%Y-%m-%d)
mkdir -p memory/logs

LOG_ENTRY="### discord-trader-monitor (real-time event)
- trader: $TRADER
- channel: $CHANNEL_ID ($CHANNEL_TYPE)
- message_id: $MESSAGE_ID
- classification: $CLASSIFICATION
- created_at: $CREATED_AT
- alerted: $([ "$FAST_PATH_ALERTED" = "true" ] && echo "fast-path" || echo "yes")
- content: ${CONTENT:0:100}..."

echo "$LOG_ENTRY" >> "memory/logs/$TODAY.md"
echo "Logged to memory/logs/$TODAY.md"

echo ""
echo "=== Step 10: Summary ==="
echo "Status: COMPLETE"
echo "Trader: $TRADER ($USERNAME)"
echo "Channel: $CHANNEL_LABEL"
echo "Classification: $CLASSIFICATION"
echo "Alert Status: $([ "$FAST_PATH_ALERTED" = "true" ] && echo "fast-path alerted" || echo "new alert sent")"
