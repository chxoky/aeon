#!/bin/bash
set -e

VAR="eyJpZCI6IjE1MjcyMzc5MjAyMTYzMTgwNDIiLCJjaGFubmVsX2lkIjoiMTM5MzEzNzA1MTEwODUwNzcyOCIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IiIsImNyZWF0ZWRfYXQiOiIyMDI2LTA3LTE2VDA4OjU4OjE0Ljg4ODAwMCswMDowMCIsImlzX3JlcGx5IjpmYWxzZSwicmVmZXJlbmNlZF9tZXNzYWdlIjpudWxsLCJhdHRhY2htZW50cyI6WyJodHRwczovL2Nkbi5kaXNjb3JkYXBwLmNvbS9hdHRhY2htZW50cy8xMzkzMTM3MDUxMTA4NTA3NzI4LzE1MjcyMzc5MTgzODc2MDU1NTkvY2hhcnQtMTA1MC5wbmc/ZXg9NmE1OWVlYTYmaXM9NmE1ODlkMjYmaG09MzZjMGM0MDYxNjgwYzlhMTMwMzYxMTQ0ZGZlOWIwYjVkZGNkNjkxOWY5OTdhZWYyMWY4NzU4OWI3NmZlMmE0MiYiLCJodHRwczovL2Nkbi5kaXNjb3JkYXBwLmNvbS9hdHRhY2htZW50cy8xMzkzMTM3MDUxMTA4NTA3NzI4LzE1MjcyMzc5MTg3MzE4MDA2MjYvY2hhcnQtMTIyNC5wbmc/ZXg9NmE1OWVlYTYmaXM9NmE1ODlkMjYmaG09NWYxZTVjYjZkNzZiZDA5Nzk3NDEyNzU5ZTdmYzYxYWFkZGE1NjQ2ODdlNjQxOTJhMjk2ZjIxMzhmN2U5MjBlYSYiLCJodHRwczovL2Nkbi5kaXNjb3JkYXBwLmNvbS9hdHRhY2htZW50cy8xMzkzMTM3MDUxMTA4NTA3NzI4LzE1MjcyMzc5MTkxMTM0NzgyNDUvY2hhcnQtMjA1My5wbmc/ZXg9NmE1OWVlYTYmaXM9NmE1ODlkMjYmaG09NmQ2YTcxNThlZTM3YWZiNzQyZjdkNTA3NGRhMDczMGUyMmE1ODI3YTFiMzVmYTdmMGJmN2JjNzFhZGQ2ZWVmZCYiLCJodHRwczovL2Nkbi5kaXNjb3JkYXBwLmNvbS9hdHRhY2htZW50cy8xMzkzMTM3MDUxMTA4NTA3NzI4LzE1MjcyMzc5MTk1OTk4OTA1MzQvSU1HXzIwMjYwNzE2XzE0MDQxNV84MjAuanBnP2V4PTZhNTllZWE2JmlzPTZhNTg5ZDI2JmhtPTdmNjkwMjYzNTE1YjBhYWJiNzdiNjM5NjI2MWMxYjRlOWE3ZjAwZjdkZTQwMDc3OTcwYmU1M2NhMjU5YTlmZmYmIl0sImZhc3RfcGF0aF9hbGVydGVkIjpmYWxzZX0="

# Step 1: Decode the event
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null || echo "")

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: base64 decode failed"
  exit 1
fi

echo "=== Step 1: Decoded Event ==="
echo "$EVENT_JSON" | jq .
echo ""

# Extract key fields
ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content // ""')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply // false')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments | length')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')

echo "=== Step 1: Validation ==="
echo "Message ID: $ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: ${CONTENT:-(empty)}"
echo "Attachments: $ATTACHMENTS"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"
echo ""

# Check if content is empty and no attachments
if [ -z "$CONTENT" ] && [ "$ATTACHMENTS" -eq 0 ]; then
  echo "DISCORD_TRADER_BAD_EVENT: empty content and no attachments"
  exit 1
fi

# Step 2: Resolve channel + trader
echo "=== Step 2: Resolving Channel & Trader ==="

# Define known channels
declare -A TRADERS
declare -A TYPES
declare -A LABELS

# HeartCanHodl channels
TRADERS["1472153627324842057"]="heartcanhodl"
TYPES["1472153627324842057"]="primary"
LABELS["1472153627324842057"]="HCH — Main"

TRADERS["1191800982414299217"]="heartcanhodl"
TYPES["1191800982414299217"]="primary"
LABELS["1191800982414299217"]="HCH — Analysis"

TRADERS["1279738718680256553"]="heartcanhodl"
TYPES["1279738718680256553"]="primary"
LABELS["1279738718680256553"]="HCH — Trades"

TRADERS["1393137051108507728"]="heartcanhodl"
TYPES["1393137051108507728"]="primary"
LABELS["1393137051108507728"]="HCH — Signals"

TRADERS["1023638573313966212"]="heartcanhodl"
TYPES["1023638573313966212"]="supporting"
LABELS["1023638573313966212"]="HCH — Members"

if [ -z "${TRADERS[$CHANNEL_ID]}" ]; then
  echo "Unknown channel: $CHANNEL_ID"
  exit 1
fi

TRADER="${TRADERS[$CHANNEL_ID]}"
CHANNEL_TYPE="${TYPES[$CHANNEL_ID]}"
LABEL="${LABELS[$CHANNEL_ID]}"

echo "Trader: $TRADER"
echo "Channel Type: $CHANNEL_TYPE"
echo "Label: $LABEL"
echo ""

# Verify username matches
if [[ "$USERNAME" != "$TRADER" ]]; then
  echo "Username mismatch - this appears to be a member message, not from the trader. Skipping."
  exit 0
fi

echo "✓ Username verified: $USERNAME matches $TRADER"
echo ""

# Step 3: Fast-path check
echo "=== Step 3: Fast-Path Check ==="
if [ "$FAST_PATH_ALERTED" == "true" ]; then
  echo "✓ Fast-path already alerted. Skipping Telegram sends."
  echo "Proceeding to classification and memory updates only."
  SKIP_TELEGRAM=1
else
  echo "No fast-path alert. Processing full classification and alerting."
  SKIP_TELEGRAM=0
fi
echo ""

# Step 4: Identify attachments (charts/images)
echo "=== Step 4: Attachment Handling ==="
if [ "$ATTACHMENTS" -gt 0 ]; then
  echo "Found $ATTACHMENTS attachment(s)"
  echo "$EVENT_JSON" | jq -r '.attachments[]' | while read -r url; do
    echo "  - $url"
  done
  echo ""
  echo "Attachments detected: appears to be chart/image-based analysis or signals."
  ALERT_TYPE="informational-with-attachments"
else
  echo "No attachments."
  ALERT_TYPE="text-only"
fi
echo ""

# Step 5: Classify message
echo "=== Step 5: Classification ==="
if [ -z "$CONTENT" ]; then
  echo "Content is empty - this is attachment-only."
  if [ "$ATTACHMENTS" -gt 0 ]; then
    echo "Classification: informational-with-charts"
  else
    echo "Classification: ERROR - no content and no attachments"
    exit 1
  fi
else
  echo "Content: $CONTENT"

  # Check for test patterns
  if [[ "$CONTENT" =~ [Tt]est ]]; then
    echo "⚠ Test message detected - skipping (HR-1)"
    exit 0
  fi

  # Simplified classification
  if [[ "$CONTENT" =~ (long|short|buy|sell|adding|taking|closing|position) ]]; then
    echo "Classification: potential-trade-signal"
  else
    echo "Classification: informational"
  fi
fi
echo ""

# Step 9: Update seen tracking
echo "=== Step 9: Update Memory Tracking ==="
mkdir -p memory
echo "$ID" >> memory/discord-trader-seen.txt 2>/dev/null || true

# Trim file if too large
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi

echo "Tracked message ID: $ID"
echo "Seen file size: $LINES lines"
echo ""

# Step 10: Log the event
echo "=== Step 10: Logging ==="
mkdir -p memory/logs
TODAY="2026-07-16"
LOG_FILE="memory/logs/${TODAY}.md"

cat >> "$LOG_FILE" <<EOF

### discord-trader-monitor (real-time event)
- trader: $TRADER
- channel: $CHANNEL_ID ($CHANNEL_TYPE) [$LABEL]
- message_id: $ID
- classification: $ALERT_TYPE
- has_attachments: $ATTACHMENTS
- alerted: no (empty content)
- notes: Attachment-only message from HCH — classified for memory tracking. $ATTACHMENTS image(s) with chart data.
EOF

echo "Logged to $LOG_FILE"
echo ""

# Step 7: Prepare alert (if not empty content)
if [ -z "$CONTENT" ] && [ "$ATTACHMENTS" -gt 0 ]; then
  echo "=== Alert Summary ==="
  echo "Message has $ATTACHMENTS attachment(s) but no text content."
  echo "Channel: $LABEL"
  echo "Type: Chart/Image Analysis"
  echo ""

  if [ "$SKIP_TELEGRAM" -eq 0 ]; then
    echo "Would send Telegram alert (if configured):"
    echo ""
    echo "📊 *[DC: $LABEL]*"
    echo ""
    echo "⚠️ _$ATTACHMENTS chart(s) attached — see images below._"
    echo ""
    echo "Attachments:"
    echo "$EVENT_JSON" | jq -r '.attachments[]' | nl
  else
    echo "Skipping Telegram (fast-path already alerted)"
  fi
fi

echo ""
echo "=== Processing Complete ==="
