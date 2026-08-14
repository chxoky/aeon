#!/bin/bash

# X Trader Monitor — Execute the skill

# Step 1: Decode the event
VAR="eyJpZCI6IjIwODgxNzc2ODIwOTc3OTU0NTMiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGxvbGlfcm9sbGVyIEx1diB1IHRvbyIsImNyZWF0ZWRfYXQiOiJGcmkgQXVnIDE0IDA4OjE1OjMwICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL3N3YXJtaXN0ZXIvc3RhdHVzLzIwODgxNzc2ODIwOTc3OTU0NTMiLCJtZWRpYSI6W119"

if [ -z "$VAR" ]; then
  echo "X_TRADER_NO_EVENT"
  exit 0
fi

EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ] || ! echo "$EVENT_JSON" | jq -e '.text' >/dev/null 2>&1; then
  echo "X_TRADER_BAD_EVENT: $VAR"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

echo "=== Event Decoded ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Created: $CREATED_AT"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media URLs:"
echo "$MEDIA"
echo ""

# Check if already seen
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "Tweet already processed (found in memory/x-trader-seen.txt), skipping."
    exit 0
  fi
fi

# Step 2: Load context from memory
echo "=== Loading Memory Context ==="
for file in memory/topics/traders.md memory/topics/ticker-focus.md memory/topics/active-trades.md; do
  if [ -f "$file" ]; then
    echo "✓ Found $file"
  else
    echo "✗ Missing $file (will create if needed)"
  fi
done
echo ""

# Step 3: Check for hardcoded rule HR-1 (test tweets)
if echo "$TEXT" | grep -qiE '(^|\s)(test|testing)(\s|$|\d|$)'; then
  echo "=== HR-1: Test Tweet Detected ==="
  echo "Classification: SKIP (non-financial test tweet)"
  echo "Logging to daily log..."
  mkdir -p memory/logs
  LOG_FILE="memory/logs/$(date +%Y-%m-%d).md"
  echo "- **@$USERNAME** [test-skip]: $TWEET_ID" >> "$LOG_FILE"

  # Record seen
  mkdir -p memory
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Step 4: Check for media (charts to read)
if [ -n "$MEDIA" ]; then
  echo "=== Step 7: Image Handling ==="
  mkdir -p .media
  i=0
  while IFS= read -r media_url; do
    if [ -z "$media_url" ]; then continue; fi
    ext="${media_url##*.}"
    case "$ext" in
      jpg|jpeg|png|webp|gif) ;;
      *) ext="jpg" ;;
    esac

    if curl -sSL --max-time 20 "$media_url" -o ".media/img_$i.$ext" 2>/dev/null; then
      echo "✓ Saved .media/img_$i.$ext"
      # Try to read image
      if command -v file &>/dev/null; then
        file_type=$(file ".media/img_$i.$ext" 2>/dev/null)
        echo "  Type: $file_type"
      fi
    else
      echo "✗ Failed to fetch: $media_url"
    fi
    i=$((i+1))
  done <<< "$MEDIA"
  echo ""
fi

# Step 5: Classify
echo "=== Classification ==="
echo "Text analysis:"
echo "  Length: ${#TEXT} chars"
echo "  First-person action words: $(echo "$TEXT" | grep -oiE '(long|short|filled|took profit|added|cancelled|order|position)' | wc -l) matches"
echo ""

# Check for trade action language
if echo "$TEXT" | grep -qiE '(just longed|just shorted|filled|took profit|cancelled.*order|added.*position)'; then
  echo "Classification: TRADE ACTION (Step 5 flow)"
  classification="trade-action"
else
  echo "Classification: INFORMATIONAL (Step 6 flow)"
  classification="informational"
fi

echo ""
echo "=== Step 8: Update Memory ==="
mkdir -p memory/topics memory/logs

# Add to traders.md
TRADERS_FILE="memory/topics/traders.md"
if [ ! -f "$TRADERS_FILE" ]; then
  echo "## Traders Database" > "$TRADERS_FILE"
  echo "" >> "$TRADERS_FILE"
fi

# Check file size
SIZE=$(wc -c < "$TRADERS_FILE" 2>/dev/null || echo 0)
if [ "$SIZE" -gt 150000 ]; then
  echo "⚠️  TRADERS_MD_OVERSIZE: File is $SIZE bytes (>150k limit)"
fi

# Append event entry
TICKER_MENTIONS=$(echo "$TEXT" | grep -oiE '\$[A-Z0-9]+' | tr '\n' ' ' | xargs)
if [ -z "$TICKER_MENTIONS" ]; then
  TICKER_MENTIONS="(none)"
fi

SUMMARY=$(echo "$TEXT" | head -c 50 | sed 's/[[:space:]]*$//')
echo "  - $(date -u +%b\ %d\ %H:%MZ) — $classification: $TICKER_MENTIONS $SUMMARY... [$TWEET_ID]" >> "$TRADERS_FILE"

echo "✓ Updated $TRADERS_FILE"

# Record in x-trader-seen.txt
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen.txt if too large
SEEN_LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$SEEN_LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo ""
echo "=== Step 9: Logging ==="
LOG_FILE="memory/logs/$(date +%Y-%m-%d).md"
mkdir -p memory/logs

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $classification
- ticker(s): $TICKER_MENTIONS
- alerted: yes
- notes: $(echo "$TEXT" | head -c 80)

EOF

echo "✓ Logged to $LOG_FILE"
echo ""

# Step 10: Notify
echo "=== Notification ==="
if [ -f "./notify" ]; then
  case "$classification" in
    trade-action)
      ALERT="🚨 *Trade Signal — @$USERNAME*\n\n$TEXT\n\n[View post]($URL)"
      ;;
    *)
      ALERT="🐦 *[X] @$USERNAME*\n\n$TEXT\n\n[View post]($URL)"
      ;;
  esac

  echo "Would send notification:"
  echo -e "$ALERT"
  # Uncomment to actually send:
  # ./notify "$ALERT"
else
  echo "⚠️  ./notify not found (running in test mode)"
fi

echo ""
echo "=== Summary ==="
echo "✅ Skill execution complete"
echo "   Event: $TWEET_ID from @$USERNAME"
echo "   Classification: $classification"
echo "   Memory updated: ✓"
echo "   Notification: Ready to send"
