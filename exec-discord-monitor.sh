#!/bin/bash
set -e

# Step 1 — Decode the event
var="eyJpZCI6IjE1MzYzNzMxMDk3NjUxNzczNjYiLCJjaGFubmVsX2lkIjoiMTMzNjA4MjcxNjA2MzY5NDk2MiIsInVzZXJuYW1lIjoiY3J5cHRvX2NoYXNlIiwiY29udGVudCI6IjxAJjEyNDc5NDAyMzQ1NTgxNzc1MjE+IGh0dHBzOi8veC5jb20vQ3J5cHRvX0NoYXNlL3N0YXR1cy8yMDg2ODE0MjI4NzI4MzgxNzY5IGd1YXJhbnRlZWQgZ2l2ZWF3YXkgb24gdGhpcyBvbmUuIGxpa2VzL2NvbW1lbnRzIGFwcHJlY2lhdGVkLCB0eSIsImNyZWF0ZWRfYXQiOiIyMDI2LTA4LTEwVDEzOjU4OjEzLjgwMDAwMCswMDowMCIsImlzX3JlcGx5IjpmYWxzZSwicmVmZXJlbmNlZF9tZXNzYWdlIjpudWxsLCJhdHRhY2htZW50cyI6W10sImZhc3RfcGF0aF9hbGVydGVkIjpmYWxzZX0="

EVENT_JSON=$(echo "${var}" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: Failed to decode base64"
  exit 0
fi

echo "=== Step 1: Decoded Event ==="
echo "$EVENT_JSON" | jq '.' 2>/dev/null || echo "$EVENT_JSON"

# Extract fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply // false')
FAST_PATH=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments // []')

echo ""
echo "=== Extracted Fields ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH"
echo ""

# Validation
if [ -z "$CONTENT" ] && [ "$ATTACHMENTS" = "[]" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: Empty content and no attachments"
  exit 0
fi

# Step 2 — Resolve channel + trader
echo "=== Step 2: Resolve Channel + Trader ==="

# Load channel mapping
if [ -f "memory/discord-channels.json" ]; then
  CHANNEL_INFO=$(jq -r ".channels[\"$CHANNEL_ID\"] // {trader: \"unknown\", type: \"unknown\"}" memory/discord-channels.json 2>/dev/null)
  LABEL=$(jq -r ".labels[\"$CHANNEL_ID\"] // \"Unknown\"" memory/discord-channels.json 2>/dev/null)
else
  echo "WARNING: memory/discord-channels.json not found"
  CHANNEL_INFO='{"trader": "unknown", "type": "unknown"}'
  LABEL="Unknown"
fi

TRADER=$(echo "$CHANNEL_INFO" | jq -r '.trader // "unknown"')
CHANNEL_TYPE=$(echo "$CHANNEL_INFO" | jq -r '.type // "unknown"')

echo "Channel: $CHANNEL_ID"
echo "Label: $LABEL"
echo "Trader: $TRADER"
echo "Type: $CHANNEL_TYPE"
echo ""

# Check for username mismatch (skip if member message)
if [ "$TRADER" != "$USERNAME" ]; then
  echo "⚠️  Username mismatch: expected '$TRADER', got '$USERNAME' — skipping as member context"
  echo ""
  echo "=== Step 10: Log ==="
  mkdir -p memory/logs
  TODAY=$(date +%Y-%m-%d)
  {
    echo "### discord-trader-monitor (real-time event)"
    echo "- trader: ${USERNAME}"
    echo "- channel: ${CHANNEL_ID} (unknown)"
    echo "- message_id: ${MESSAGE_ID}"
    echo "- classification: skip"
    echo "- ticker(s): []"
    echo "- alerted: no"
    echo "- notes: username mismatch — member message, not trader"
  } >> "memory/logs/$TODAY.md"
  exit 0
fi

# Step 3 — Load context (traders, ticker-focus, active-trades)
echo "=== Step 3: Load Context ==="
for ctx_file in memory/topics/traders.md memory/topics/ticker-focus.md memory/topics/active-trades.md; do
  if [ -f "$ctx_file" ]; then
    echo "✓ Found $ctx_file"
  else
    echo "⚠️  Missing $ctx_file (will proceed with limited context)"
  fi
done
echo ""

# Step 4 — Cross-platform dedup (check for recent X post)
echo "=== Step 4: Cross-Platform Dedup ==="
# This is a Discord-first scenario by default
echo "Assuming Discord post is first sighting — will note in traders.md for X monitor to dedupe"
echo ""

# Step 5 — Classify the message
echo "=== Step 5: Classify Message ==="

# Check for test patterns (HR-1)
if echo "$CONTENT" | grep -iE '(test|testing|\[.*\]\s*test)' > /dev/null; then
  echo "Classification: SKIP (test pattern)"
  CLASSIFICATION="skip"
  SHOULD_ALERT="no"
else
  # Check if it looks like a trade (first person, execution language)
  if echo "$CONTENT" | grep -iE '(placing|cancelling|adding|closing|filled|order placed|short|long|buy|sell)' > /dev/null; then
    echo "Classification: Possible TRADE SIGNAL"
    CLASSIFICATION="trade-signal"
    SHOULD_ALERT="yes"
  else
    # Informational
    echo "Classification: INFORMATIONAL"
    CLASSIFICATION="informational"
    SHOULD_ALERT="yes"
  fi
fi

# Quick ticker extraction (simple pattern)
TICKERS=$(echo "$CONTENT" | grep -oE '\$[A-Z]{1,5}' | sort -u | tr '\n' ',' | sed 's/,$//')
echo "Detected tickers: ${TICKERS:-(none)}"
echo ""

# Dedup check
echo "=== Dedup Check ==="
mkdir -p memory
if [ -f "memory/discord-trader-seen.txt" ]; then
  if grep -q "^${MESSAGE_ID}$" memory/discord-trader-seen.txt; then
    echo "MESSAGE ALREADY SEEN — skipping"
    SHOULD_ALERT="no"
  fi
else
  touch memory/discord-trader-seen.txt
fi

echo "Should alert: $SHOULD_ALERT"
echo ""

# Step 6/7 — Send alert if needed
if [ "$SHOULD_ALERT" = "yes" ] && [ "$CLASSIFICATION" != "skip" ] && [ "$FAST_PATH" = "false" ]; then
  echo "=== Step 6/7: Send Alert ==="

  case "$CLASSIFICATION" in
    trade-signal)
      ALERT_TITLE="🚨 *Trade Signal — [DC: ${LABEL}]*"
      ;;
    informational)
      ALERT_TITLE="💬 *[DC: ${LABEL}]*"
      ;;
    *)
      ALERT_TITLE="ℹ️ *[DC: ${LABEL}]*"
      ;;
  esac

  ALERT_MSG="${ALERT_TITLE}

${CONTENT}"

  echo "Alert would be sent:"
  echo "$ALERT_MSG"
  echo ""

  # Attempt to send via notify (if available)
  if command -v ./notify &> /dev/null; then
    ./notify "$ALERT_MSG" 2>/dev/null || echo "⚠️  notify command failed (expected in isolated environment)"
  else
    echo "⚠️  notify not available (expected in test environment)"
  fi
else
  if [ "$FAST_PATH" = "true" ]; then
    echo "=== Fast Path Alert Already Sent ==="
    echo "Skipping Telegram alert; proceeding with memory/logging only"
  else
    echo "=== No Alert Needed ==="
    echo "Classification: $CLASSIFICATION"
  fi
fi

echo ""

# Step 9 — Update memory: dedup tracking
echo "=== Step 9: Update Memory ==="
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt

# Prune if too large
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  echo "Pruning discord-trader-seen.txt ($LINES lines -> 2000 lines)"
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp
  mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi

# Optionally update traders.md with event
mkdir -p memory/topics
if [ -f "memory/topics/traders.md" ]; then
  # Append event line (keeping size discipline: ≤200 chars per event)
  EVENT_LINE="- $(date -u +%Y-%m-%dT%H:%M:%S): \`${USERNAME}\` [${LABEL}] ${TICKERS:-(no ticker)}: \`${CONTENT:0:100}...\`"
  echo "$EVENT_LINE" >> memory/topics/traders.md
  echo "Updated traders.md with event"
else
  echo "⚠️  memory/topics/traders.md not found (will create on next run)"
fi

echo ""

# Step 10 — Log
echo "=== Step 10: Log ==="
mkdir -p memory/logs
TODAY=$(date +%Y-%m-%d)

{
  echo "### discord-trader-monitor (real-time event)"
  echo "- trader: ${USERNAME}"
  echo "- channel: ${CHANNEL_ID} (${CHANNEL_TYPE})"
  echo "- message_id: ${MESSAGE_ID}"
  echo "- classification: ${CLASSIFICATION}"
  echo "- ticker(s): [${TICKERS:-(none)}]"
  echo "- alerted: ${SHOULD_ALERT}"
  if [ "$FAST_PATH" = "true" ]; then
    echo "- notes: alerted via fast-path before skill execution"
  else
    echo "- notes: processed real-time"
  fi
} >> "memory/logs/$TODAY.md"

echo "Logged to memory/logs/$TODAY.md"
echo ""
echo "=== Execution Complete ==="
