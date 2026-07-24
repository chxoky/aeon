#!/bin/bash
set -euo pipefail

# Decode base64 event
VAR_B64="eyJpZCI6IjIwODA0OTg3NjE4MzExNzg1ODIiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGhpcm9icmluX3Ag8J+rsPCfj7wiLCJjcmVhdGVkX2F0IjoiRnJpIEp1bCAyNCAwMzo0MjoxMyArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9zd2FybWlzdGVyL3N0YXR1cy8yMDgwNDk4NzYxODMxMTc4NTgyIiwibWVkaWEiOltdfQ=="

EVENT_JSON=$(echo "$VAR_B64" | base64 -d 2>/dev/null || echo "")

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode"
  exit 0
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')

echo ""
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"

# Check for empty fields
if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: Empty text"
  exit 0
fi

# Step 2: Check if already processed
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
    echo "Already processed this tweet, skipping"
    exit 0
  fi
fi

# Record this tweet as seen
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo "Recorded tweet $TWEET_ID as seen"

# Step 3: Decode what the message is
echo ""
echo "=== Classification Analysis ==="
echo "Text to classify: '$TEXT'"

# Step 4: Classify
# Check for test tweets (hardcoded rule HR-1)
if echo "$TEXT" | grep -iE '(^|[^a-z])test([^a-z]|$)' > /dev/null; then
  echo "Classification: SKIP (test tweet - HR-1)"
  CLASSIFICATION="skip"
  ALERTED="no"
else
  # Check if this looks like a trade action (first person, execution language)
  if echo "$TEXT" | grep -iE '(just (longed|shorted|bought|sold)|filled|took profit|cancelled|added (more|to))' > /dev/null; then
    echo "Classification: TRADE ACTION DETECTED"
    CLASSIFICATION="trade-action"
    ALERTED="yes"
    # This would trigger Step 5, but we need more context from memory files
    echo ""
    echo "⚠️  TRADE SIGNAL DETECTED FROM @$USERNAME"
    echo "Text: $TEXT"
    echo "URL: $URL"
  else
    echo "Classification: INFORMATIONAL"
    CLASSIFICATION="informational"
    ALERTED="yes"
  fi
fi

# Update memory logs
TODAY=$(date -u +%Y-%m-%d)
mkdir -p memory/logs
{
  echo "### x-trader-monitor (real-time event)"
  echo "- trader: @$USERNAME"
  echo "- tweet_id: $TWEET_ID"
  echo "- classification: $CLASSIFICATION"
  echo "- alerted: $ALERTED"
  echo "- text: $TEXT"
} >> "memory/logs/$TODAY.md"

echo ""
echo "Log entry added to memory/logs/$TODAY.md"
