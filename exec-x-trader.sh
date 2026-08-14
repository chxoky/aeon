#!/bin/bash
set -eu

# Step 1: Decode the event
var="eyJpZCI6IjIwODgzMDg1NTI4OTI4NTQ2NDQiLCJ1c2VybmFtZSI6IktpbGxhWEJUIiwidGV4dCI6Ikl0IHNlZW1zIGxpa2UgJEJUQyBpcyBnb2luZyBmb3IgdGhlIDYxSyBsaXF1aWRhdGlvbnMuIFxuXG5Xb3J0aCB3YXRjaGluZywgYmVjYXVzZSBpZiB3ZSBsb3NlIHRoYXQgYXJlYSwgdGhlIHN0cnVjdHVyZSBkb2VzbuKAmXQgbG9vayBwYXJ0aWN1bGFybHkgZ3JlYXQsIGFuZCB3ZSBjb3VsZCBzZWUgYSBzd2VlcCBiZWxvdyB0aGUgNTdzLlxuXG5BcyBtZW50aW9uZWQgaW4gcHJldmlvdXMgcG9zdHMsIE1NcyB3aWxsIHNvbWV0aW1lcyBmcm9udCBydW4gbWFqb3Igc2hvcnQgbGlxdWlkYXRpb25zIHRvIG1ha2UgcGVvcGxlIG92ZXJjb25maWRlbnQgaW4gdGhlaXIgc2hvcnRzLCBqdXN0IGFzIHRoZSBtYXJrZXQgaXMgYWN0dWFsbHkgc2hpZnRpbmcgaW50byBhIG5ldyB0cmVuZC4gUmlnaHQgbm93LCBpdCBsb29rcyBsaWtlIHdl4oCZcmUgaW4gbW9yZSBvZiBhIGxvbmcgaHVudGluZyBwaGFzZSBvZiB0aGUgY3ljbGUuIiwiY3JlYXRlZF9hdCI6IkZyaSBBdWcgMTQgMTY6NTU6MzIgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vS2lsbGFYQlQvc3RhdHVzLzIwODgzMDg1NTI4OTI4NTQ2NDQiLCJtZWRpYSI6WyJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSFBzcEJiSVhFQUFtbUE1LnBuZyIsImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IUGNZNHRSV0VBQTZ0V2cuanBnIl19"

EVENT_JSON=$(echo "${var}" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: unable to decode var"
  exit 0
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null || echo "")
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null || echo "")
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null || echo "")
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at' 2>/dev/null || echo "")
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null || echo "")
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null || echo "")

echo "=== Step 1: Event Decoded ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Created: $CREATED_AT"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media: $MEDIA"
echo ""

# Step 2: Check if already processed
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "This tweet was already processed. Skipping."
    exit 0
  fi
fi

# Step 3: Load memory context
echo "=== Step 2: Loading Memory Context ==="

if [ -f "memory/topics/traders.md" ]; then
  echo "Found traders.md"
else
  echo "Note: traders.md not found (first run?)"
fi

if [ -f "memory/topics/ticker-focus.md" ]; then
  echo "Found ticker-focus.md"
else
  echo "Note: ticker-focus.md not found"
fi

if [ -f "memory/topics/active-trades.md" ]; then
  echo "Found active-trades.md"
else
  echo "Note: active-trades.md not found"
fi

echo ""

# Step 4: Classify the post
echo "=== Step 3: Classifying Post ==="

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -iE '(test|testing)' > /dev/null; then
  echo "Classification: TEST_TWEET (silent skip per HR-1)"
  CLASSIFICATION="test_tweet"
  ALERT=false
else
  # Check if this is a personal action (Step 5)
  if echo "$TEXT" | grep -iE '(just longed|just shorted|filled my limit|took profit|cancelled|added|closing|entered|opened)' > /dev/null; then
    echo "Classification: TRADE_ACTION (personal action signal)"
    CLASSIFICATION="trade_action"
    ALERT=true
  else
    echo "Classification: INFORMATIONAL (market opinion/levels/commentary)"
    CLASSIFICATION="informational"
    ALERT=true
  fi
fi

echo ""

# Step 5: Handle media (Step 7)
if [ -n "$MEDIA" ]; then
  echo "=== Step 4: Fetching Media ==="
  mkdir -p .media
  i=0
  for u in $MEDIA; do
    ext="${u##*.}"
    case "$ext" in
      jpg|jpeg|png|webp|gif) : ;;
      *) ext=jpg ;;
    esac

    if curl -sSL --max-time 20 "$u" -o ".media/img_$i.$ext" 2>/dev/null; then
      echo "✓ Saved .media/img_$i.$ext"
    else
      echo "✗ Failed to fetch media"
    fi
    i=$((i+1))
  done
  echo ""
fi

# Step 6: Alert logic
if [ "$ALERT" = true ]; then
  echo "=== Step 5: Generating Alert ==="

  case "$CLASSIFICATION" in
    informational)
      echo "Alert Type: Informational"
      echo ""
      echo "🐦 *[X] @$USERNAME*"
      echo ""
      echo "$TEXT"
      echo ""
      echo "[View tweet]($URL)"
      echo ""
      echo "→ This is a market opinion/commentary. Recording in memory."
      ;;
    trade_action)
      echo "Alert Type: Trade Signal (Personal Action)"
      echo ""
      echo "🚨 *Trade Signal — @$USERNAME*"
      echo ""
      echo "$TEXT"
      echo ""
      echo "[View post]($URL)"
      echo ""
      echo "→ Awaiting Kyle's approval to mirror on Kraken"
      ;;
  esac
else
  echo "=== Step 5: No Alert ==="
  echo "Classification: $CLASSIFICATION → silent skip"
fi

echo ""

# Step 7: Update memory
echo "=== Step 6: Updating Memory ==="

mkdir -p memory/topics memory/logs

# Add to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen list if it gets too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "Trimmed x-trader-seen.txt to last 2000 entries"
fi

# Log to daily log
TODAY=$(date +%Y-%m-%d)
LOG_FILE="memory/logs/$TODAY.md"

mkdir -p memory/logs
if [ ! -f "$LOG_FILE" ]; then
  echo "# $TODAY" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- alerted: $([ "$ALERT" = true ] && echo "yes" || echo "no")
- url: $URL
EOF

echo "✓ Updated memory/x-trader-seen.txt"
echo "✓ Updated $LOG_FILE"
echo ""

echo "=== Complete ==="
echo "Classification: $CLASSIFICATION"
echo "Alert sent: $([ "$ALERT" = true ] && echo "YES" || echo "NO")"
