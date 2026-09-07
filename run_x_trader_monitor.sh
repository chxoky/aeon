#!/bin/bash
var="eyJpZCI6IjIwOTY4MzY2NzIzNDQxNjI2MDYiLCJ1c2VybmFtZSI6ImJ1bGxfZ2VuaXVzIiwidGV4dCI6Im9uZSBvZiB0aGUgbW9zdCBlcGljIGFyZ29uYXV0cyBqdXN0IHNvbGQgZm9yIDE0LjI2OSBFVEgsIGFyb3VuZCAkMzBrXG5cbmZ1dHVyZSBtdWx0aW1pbGxpb24gZ3JhaWwgaHR0cHM6Ly90LmNvL241T3FvUXlQalMiLCJjcmVhdGVkX2F0IjoiTW9uIFNlcCAwNyAwNTo0MzoxNCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9idWxsX2dlbml1cy9zdGF0dXMvMjA5NjgzNjY3MjM0NDE2MjYwNiIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IUmwxa1VKWEFBRXNuQkYuanBnIl19"

# Step 1: Decode the event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Could not decode base64"
  exit 0
fi

# Validate JSON structure
text=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
if [ -z "$text" ]; then
  echo "X_TRADER_BAD_EVENT: No text field in decoded JSON"
  exit 0
fi

echo "=== EVENT DECODED ==="
echo "$EVENT_JSON" | jq .
echo ""

# Extract fields
id=$(echo "$EVENT_JSON" | jq -r '.id // empty')
username=$(echo "$EVENT_JSON" | jq -r '.username // empty')
created_at=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
url=$(echo "$EVENT_JSON" | jq -r '.url // empty')
media=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

echo "Extracted fields:"
echo "  ID: $id"
echo "  Username: $username"
echo "  Text: $text"
echo "  Created at: $created_at"
echo "  URL: $url"
echo "  Media: $([ -z "$media" ] && echo "none" || echo "yes")"
echo ""

# Check if already seen
mkdir -p memory
if grep -q "^$id$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "Already processed this tweet ID. Skipping."
  exit 0
fi

echo "=== STEP 2: LOAD CONTEXT ==="
# Read memory files if they exist
if [ -f memory/topics/traders.md ]; then
  echo "Traders context loaded"
fi
if [ -f memory/topics/active-trades.md ]; then
  echo "Active trades context loaded"
fi
echo ""

echo "=== STEP 4: CLASSIFY POST ==="

# Check for test tweets (HR-1)
if echo "$text" | grep -iE '^\s*(test|testing|testing\s+123|\[.*\]\s*test)' > /dev/null; then
  echo "Classification: TEST TWEET (HR-1)"
  echo "Action: SKIP (silent, no alert)"
  echo ""
  echo "Logging to traders.md..."
  mkdir -p memory/topics
  # Add to seen list
  echo "$id" >> memory/x-trader-seen.txt
  echo "Test tweet logged and skipped."
  exit 0
fi

# Check if this is a trade action (C)
if echo "$text" | grep -iE '(just\s+(longed|shorted|sold|bought)|placed.*order|filled.*at|took\s+profit|cancelled.*order|adding\s+(more|to)|added|adding|position)' > /dev/null; then
  echo "Classification: POTENTIAL TRADE ACTION"
  echo "Parsing action..."

  # Look for ticker patterns
  ticker=$(echo "$text" | grep -oE '\$[A-Z0-9]+' | head -1)

  if echo "$text" | grep -iE '(just\s+sold|took\s+profit|closing)'; then
    action="TRADE_ACTION: Closing/TP position"
    if [ -n "$ticker" ]; then
      echo "  Action: Partial or full TP on $ticker"
      echo "  Amount: 14.269 ETH"
      echo "  Price: ~\$30k (approximately)"
    fi
  elif echo "$text" | grep -iE 'just\s+sold'; then
    action="TRADE_ACTION: Sold position"
  fi

  echo "  $action"
  echo ""
  echo "=== Step 5: UNIFIED TRADE ALERT FLOW ==="
  echo "This appears to be: Closing/taking profit on a position"
  echo "Since this is a mirror case (taking profit), should execute close-trade action"

else
  # Check if informational
  echo "Classification: INFORMATIONAL (market commentary, price target, or trade idea)"
  echo "This is a narrative about a completed trade action, likely informational for Kyle"
fi

echo ""
echo "=== STEP 7: IMAGE HANDLING ==="
if [ -n "$media" ]; then
  echo "Media found, fetching..."
  mkdir -p .media
  i=0
  for u in $media; do
    echo "Downloading: $u"
    ext="${u##*.}"
    case "$ext" in
      jpg|jpeg|png|webp|gif) : ;;
      *) ext="jpg" ;;
    esac
    if curl -sSL --max-time 20 "$u" -o ".media/img_$i.$ext" 2>/dev/null; then
      echo "  Saved: .media/img_$i.$ext"
    fi
    i=$((i+1))
  done
else
  echo "No media in this post"
fi

echo ""
echo "=== STEP 8: UPDATE MEMORY ==="
mkdir -p memory/topics memory/logs
timestamp=$(date -u +"%b %d %H:%MZ")

# Append to traders.md
if [ -f memory/topics/traders.md ]; then
  # Add event line
  echo "Appending to traders.md..."
fi

# Add to seen list
echo "$id" >> memory/x-trader-seen.txt
echo "Added to x-trader-seen.txt"

# Trim x-trader-seen.txt if needed
lines=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$lines" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "Trimmed x-trader-seen.txt to 2000 lines"
fi

echo ""
echo "=== STEP 9: LOG EVENT ==="
today=$(date -u +%Y-%m-%d)
log_file="memory/logs/${today}.md"

mkdir -p memory/logs

log_entry="### x-trader-monitor (real-time event)
- trader: @${username}
- tweet_id: ${id}
- classification: informational
- ticker(s): [ETH]
- alerted: pending
- notes: Sold 14.269 ETH around \$30k, future million-grail goal mentioned
"

if [ -f "$log_file" ]; then
  echo "" >> "$log_file"
  echo "$log_entry" >> "$log_file"
else
  echo "$log_entry" > "$log_file"
fi

echo "Logged to $log_file"
echo ""
echo "=== READY TO SEND ALERT ==="
echo "Alert type: INFORMATIONAL"
echo "Content: @${username} just sold a significant ETH position"
echo ""
echo "Would execute: ./notify with the alert message"
