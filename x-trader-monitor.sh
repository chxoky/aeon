#!/bin/bash
set -e

TWEET_ID='2077722378696581280'
MEMORY_DIR='/home/runner/work/aeon/aeon/memory'
SEEN_FILE="$MEMORY_DIR/x-trader-seen.txt"

# Check if tweet ID already seen
if [ -f "$SEEN_FILE" ] && grep -q "^${TWEET_ID}$" "$SEEN_FILE"; then
  echo "X_TRADER_DUPLICATE_EVENT"
  exit 0
fi

# Add to seen list
mkdir -p "$MEMORY_DIR"
echo "$TWEET_ID" >> "$SEEN_FILE"

# Trim if over 5000 lines (keep last 2000)
LINES=$(wc -l < "$SEEN_FILE" 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 "$SEEN_FILE" > "$SEEN_FILE.tmp"
  mv "$SEEN_FILE.tmp" "$SEEN_FILE"
fi

echo "SUCCESS: Classification A (non-financial) — logged silently"
