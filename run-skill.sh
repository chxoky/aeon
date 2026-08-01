#!/bin/bash
set -e

var="eyJpZCI6IjIwODM1NzM2NTQ4MzE0MjM2NTciLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQHhidDIwMjcgSGkiLCJjcmVhdGVkX2F0IjoiU2F0IEF1ZyAwMSAxNToyMDo0NCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9zd2FybWlzdGVyL3N0YXR1cy8yMDgzNTczNjU0ODMxNDIzNjU3IiwibWVkaWEiOltdfQ=="

# Step 1: Decode event
EVENT_JSON=$(echo "$var" | base64 -d)

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null || echo "")

echo "=== Decoded Event ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media: $MEDIA"
echo ""

# Step 2: Check if already seen
if grep -q "^$TWEET_ID" memory/x-trader-seen.txt 2>/dev/null; then
  echo "Tweet already processed, skipping."
  exit 0
fi

# Step 3: Classify the post
echo "=== Classification ==="

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -qiE '(^test|test$|test[ing]{3}|testing 123|\[.*\]\s*test)'; then
  echo "Classification: NON-FINANCIAL (test tweet)"
  echo "Action: Skip silently"
  mkdir -p memory
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Check if it's a personal action (Step 4C)
if echo "$TEXT" | grep -qiE '(just (longed|shorted|closed|sold)|filled my|took profit|cancelled my|added more|placed|market order|limit order|opening|entering)'; then
  echo "Classification: TRADE SIGNAL (personal action)"

  # Send trade alert
  MESSAGE="🚨 *Trade Signal — @$USERNAME*

$TEXT

[View post]($URL)"

  ./notify "$MESSAGE"

  # Update memory
  mkdir -p memory
  echo "$TWEET_ID" >> memory/x-trader-seen.txt

  # Log
  mkdir -p memory/logs
  cat >> memory/logs/2026-08-01.md <<EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: trade-new-entry
- text: $TEXT
- alerted: yes
- notes: Trade signal detected based on personal action language

EOF

  exit 0
fi

# Default: informational
echo "Classification: INFORMATIONAL (trader opinion/commentary)"

MESSAGE="🐦 *[X] @$USERNAME*

$TEXT

[View tweet]($URL)"

./notify "$MESSAGE"

# Update memory
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Log
mkdir -p memory/logs
cat >> memory/logs/2026-08-01.md <<EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: informational
- text: $TEXT
- alerted: yes
- notes: General comment or market opinion

EOF

echo "Alert sent."
