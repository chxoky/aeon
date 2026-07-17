#!/bin/bash

var="eyJpZCI6IjIwNzgxNDgyOTgwMzcxODY2NTUiLCJ1c2VybmFtZSI6InRfaW5fY3J5cHRvIiwidGV4dCI6IkBtcl9zYXFpYl82IER1ZGUsIEknbSBub3QgeW91ciBtb20sIHNvIHlvdSBkb24ndCBoYXZlIHRvIHRlbGwgbWUgZXZlcnl0aGluZyB5b3UgZG8iLCJjcmVhdGVkX2F0IjoiRnJpIEp1bCAxNyAxNjowMjoxOSArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS90X2luX2NyeXB0by9zdGF0dXMvMjA3ODE0ODI5ODAzNzE4NjY1NSIsIm1lZGlhIjpbXX0="

# Step 1: Decode the event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: decode failed"
  exit 1
fi

# Parse JSON
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media | join(",")')

echo "=== DECODED EVENT ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media: $MEDIA"

# Check if tweet is already seen
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
    echo "=== DUPLICATE ==="
    echo "Tweet ID $TWEET_ID already processed"
    exit 0
  fi
fi

# Add to seen list
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo "=== ADDED TO SEEN LIST ==="
