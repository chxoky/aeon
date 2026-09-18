#!/bin/bash
set -e

# Step 1: Decode the event
VAR="eyJpZCI6IjIxMDA4MTc4NDIwOTA1MTY1MjMiLCJ1c2VybmFtZSI6IkhlYXJ0Q2FuSG9kbCIsInRleHQiOiJNYXJrZXQgc2V0cyBhbiBleGFtcGxlIGJlZm9yZSByZXN1bWluZyIsImNyZWF0ZWRfYXQiOiJGcmkgU2VwIDE4IDA1OjIyOjU5ICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL0hlYXJ0Q2FuSG9kbC9zdGF0dXMvMjEwMDgxNzg0MjA5MDUxNjUyMyIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IU1R1a3NpYmNBQXlRRjYuanBnIl19"

EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq . 2>/dev/null || echo "$EVENT_JSON"

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)

if [ -z "$TEXT" ] || [ -z "$USERNAME" ]; then
  echo "X_TRADER_BAD_EVENT: missing text or username"
  exit 1
fi

echo ""
echo "=== Parsed Fields ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"

# Check for media
MEDIA_URLS=$(echo "$EVENT_JSON" | jq -r '.media[]? // empty' 2>/dev/null)
if [ -n "$MEDIA_URLS" ]; then
  echo "Has media: yes"
  echo "Media URLs:"
  echo "$MEDIA_URLS"
else
  echo "Has media: no"
fi

# Step 2: Check if already seen (dedup against redelivery)
mkdir -p memory
if [ -f memory/x-trader-seen.txt ] && grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
  echo ""
  echo "⚠️ Already processed this tweet (cached), skipping to avoid duplicate alert"
  exit 0
fi

echo ""
echo "=== Step 3: Load Context ==="

# Load memory files if they exist
if [ -f memory/topics/traders.md ]; then
  echo "✓ Loaded traders.md context"
fi

if [ -f memory/topics/ticker-focus.md ]; then
  echo "✓ Loaded ticker-focus.md context"
fi

if [ -f memory/topics/active-trades.md ]; then
  echo "✓ Loaded active-trades.md context"
fi

echo ""
echo "=== Step 4: Classification ==="

# HR-1: Check for test tweets
if echo "$TEXT" | grep -iqE '(^test|test$|\[.+\]\s+test|test.*\[|testing\s*123|^testing$)'; then
  echo "Classification: NON-FINANCIAL (test tweet)"
  echo "Action: SKIP SILENTLY"

  # Still log to daily logs for activity tracking
  mkdir -p memory/logs
  TODAY=$(date +%Y-%m-%d)
  cat >> "memory/logs/$TODAY.md" <<EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: skip (test-tweet)
- alerted: no
- notes: Matched HR-1 test pattern
EOF

  # Record seen ID to prevent redelivery
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Step 4A: Non-financial check
if echo "$TEXT" | grep -iqE '(meme|lol|haha|retweet|meta|platform|personal|thread|just saying|imo)'; then
  echo "→ Likely non-financial (personal/meta/meme)"
fi

# Step 4B: Check if cryptic or has images
echo "→ Text length: ${#TEXT} chars"
if [ -n "$MEDIA_URLS" ]; then
  echo "→ HAS MEDIA - fetching image to read chart..."
  mkdir -p .media
  i=0
  for u in $MEDIA_URLS; do
    ext="${u##*.}"
    case "$ext" in
      jpg|jpeg|png|webp|gif) : ;;
      *) ext=jpg ;;
    esac
    if curl -sSL --max-time 20 "$u" -o ".media/img_$i.$ext" 2>/dev/null; then
      echo "  → Saved .media/img_$i.$ext"
    fi
    i=$((i+1))
  done
fi

# Step 4C: Check for trade action signals
echo ""
echo "=== Parsing for Trade Signals ==="

# Look for position action language
if echo "$TEXT" | grep -iqE '(just (long|short|entered|placed|longed|shorted|TP|closed|cancelled|added)|filled|took profit|stopped out|added more|scaled|cancelled my|closing my)'; then
  echo "→ DETECTED: First-person execution language"

  # Extract ticker if present (simple pattern: $TICKER or single word capitalization)
  TICKER=$(echo "$TEXT" | grep -oE '\$[A-Z]+|^[A-Z]+|[[:space:]][A-Z]+' | head -1 | sed 's/[[:space:]]//g')

  if [ -n "$TICKER" ]; then
    echo "→ Ticker: $TICKER"
  fi

  echo ""
  echo "✅ This appears to be a TRADE SIGNAL"
  echo ""
  echo "Alert Template:"
  echo "🚨 *Trade Signal — @$USERNAME*"
  echo ""
  echo "\"\$TICKER — {LONG/SHORT} — {LIMIT/MARKET}"
  echo ""
  echo "\"$TEXT\""
  echo ""
  echo "[View post]($URL)"
  echo ""
  echo "Reply \`approve TICKER\` to mirror, or ignore to skip."
else
  echo "→ No first-person execution language detected"
  echo "→ This is INFORMATIONAL (opinion/level/prediction)"
  echo ""
  echo "✅ This is an INFORMATIONAL ALERT"
  echo ""
  echo "Alert Template:"
  echo "🐦 *[X] @$USERNAME*"
  echo ""
  echo "\"$TEXT\""
  echo ""
  echo "[View tweet]($URL)"
fi

echo ""
echo "=== Step 8: Update Memory ==="

# Record the tweet ID to prevent reprocessing
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen.txt if too large (keep last 2000)
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Log the event
mkdir -p memory/logs
TODAY=$(date +%Y-%m-%d)

# Determine classification for log
if echo "$TEXT" | grep -iqE '(just (long|short|entered|placed|longed|shorted|TP|closed|cancelled|added)|filled|took profit|stopped out|added more|scaled|cancelled my|closing my)'; then
  CLASSIFICATION="trade-signal"
  ALERTED="pending-approval"
else
  CLASSIFICATION="informational"
  ALERTED="yes"
fi

cat >> "memory/logs/$TODAY.md" <<EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker: $TICKER
- text: $TEXT
- alerted: $ALERTED
- url: $URL
EOF

echo "✓ Logged to memory/logs/$TODAY.md"
echo "✓ Added to x-trader-seen.txt"

echo ""
echo "=== Step 9: Ready to Notify ==="
echo ""
echo "Summary:"
echo "- Username: @$USERNAME"
echo "- Classification: $CLASSIFICATION"
echo "- Action: $([ "$ALERTED" = "yes" ] && echo 'Send alert to Kyle' || echo 'Awaiting approval')"
