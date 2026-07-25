#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon

# Read the var and decode
EVENT_JSON=$(cat .event-var | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: failed to decode base64"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)

echo "=== Event Decoded ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"

# Validate
if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: empty text field"
  exit 1
fi

# Check if already seen
if [ -f "memory/x-trader-seen.txt" ] && grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
  echo "DUPLICATE: Already processed tweet $TWEET_ID, skipping"
  exit 0
fi

# Load memory context if available
echo ""
echo "=== Memory Context ==="
if [ -f "memory/topics/traders.md" ]; then
  echo "Found traders.md"
  grep -A 5 "@$USERNAME" memory/topics/traders.md 2>/dev/null || echo "No existing context for @$USERNAME"
fi

# Step 4: Classify the post
echo ""
echo "=== Classification ==="

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -iE '(^|[^a-z])test([^a-z]|$)|testing|test[ing]? 123' > /dev/null; then
  echo "Classification: SKIP (test tweet per HR-1)"
  CLASSIFICATION="skip"
  ALERTED="no"
elif echo "$TEXT" | grep -oE '\$[A-Z]' > /dev/null || echo "$TEXT" | grep -iE '(long|short|buy|sell|crypto|btc|eth|bitcoin|ethereum|trade|position|entry|target|level|support|resistance)' > /dev/null; then
  # Financial-related content
  if echo "$TEXT" | grep -iE '(just |^)(long|short|buy|sell|filled|took profit|closing|cancelled|added|adding to|TP|SL)' > /dev/null; then
    # Personal action
    echo "Classification: TRADE_ACTION"
    CLASSIFICATION="trade-signal"
    ALERTED="yes"
  else
    # Informational only (no personal action)
    echo "Classification: INFORMATIONAL"
    CLASSIFICATION="informational"
    ALERTED="yes"
  fi
else
  # Non-financial: personal life, memes, retweets, platform meta, generic banter
  echo "Classification: SKIP (non-financial)"
  CLASSIFICATION="skip"
  ALERTED="no"
fi

echo "Result: $CLASSIFICATION (alert=$ALERTED)"

# If we should alert, do it now
if [ "$ALERTED" = "yes" ]; then
  # Extract ticker if present
  TICKER=$(echo "$TEXT" | grep -oE '\$[A-Z]+' | head -1)

  echo ""
  echo "=== Sending Alert ==="
  if [ "$CLASSIFICATION" = "trade-signal" ]; then
    ./notify "🚨 *Trade Signal — @$USERNAME*

$TEXT

${TICKER:+[$TICKER] - }View post: $URL"
  else
    ./notify "🐦 *@$USERNAME*

$TEXT

View: $URL"
  fi
else
  echo "Skipping alert (non-financial or test)"
fi

# Update memory
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen list if too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Log entry
mkdir -p memory/logs
TODAY=$(date +%Y-%m-%d)
cat >> "memory/logs/$TODAY.md" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker(s): [${TICKER:-none}]
- alerted: $ALERTED
- notes: Non-financial personal commentary
EOF

echo ""
echo "=== Complete ==="
echo "Classification: $CLASSIFICATION"
echo "Alert sent: $ALERTED"
echo "Event logged to memory/logs/$TODAY.md"
