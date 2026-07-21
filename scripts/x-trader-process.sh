#!/bin/bash
set -e

# Decode the base64-encoded event
VAR="${1}"
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_NO_EVENT"
  exit 0
fi

# Extract fields
ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: $VAR"
  exit 0
fi

# Check if we've already seen this tweet
mkdir -p memory
if grep -q "^$ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "Already processed tweet $ID, skipping..."
  exit 0
fi

# Store in seen list
echo "$ID" >> memory/x-trader-seen.txt

# Trim seen list if too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo "=== Event Decoded ==="
echo "ID: $ID"
echo "Username: $USERNAME"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo ""
echo "=== Text ==="
echo "$TEXT"
echo ""
