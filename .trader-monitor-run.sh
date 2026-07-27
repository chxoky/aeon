#!/bin/bash
set -e

var='eyJpZCI6IjIwODE1OTY3MTYzMTEwMTk5MTgiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQEZhbGNvbnlGYWxjb24gOigiLCJjcmVhdGVkX2F0IjoiTW9uIEp1bCAyNyAwNDoyNTowNiArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9zd2FybWlzdGVyL3N0YXR1cy8yMDgxNTk2NzE2MzExMDE5OTE4IiwibWVkaWEiOltdfQ=='

# Step 1: Decode the base64 event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)

echo ""
echo "=== Extracted Fields ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"

# Step 1 validation
if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: text is empty"
  exit 1
fi

# Check if tweet already processed
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "DUPLICATE: Tweet $TWEET_ID already processed"
    exit 0
  fi
fi

echo ""
echo "=== Step 4: Classification ==="

# HR-1: Test tweets
if echo "$TEXT" | grep -qi '\btest\b'; then
  echo "CLASSIFICATION: SKIP (test tweet)"
  # Add to seen
  mkdir -p memory
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Analyze the text
echo "Tweet text: $TEXT"
echo "Username: $USERNAME"

# HR-2: Check for personal actions (first person, execution-oriented)
# Looking for: "just longed", "filled", "took profit", "cancelled", "added"
if echo "$TEXT" | grep -qiE 'just (longed|shorted|bought|sold)|filled|took profit|taking profit|cancelled|added'; then
  echo "CLASSIFICATION: TRADE SIGNAL (personal action detected)"
  ACTION="potential_trade_action"
else
  echo "CLASSIFICATION: INFORMATIONAL or CRYPTIC"
  ACTION="informational"
fi

echo ""
echo "=== Summary ==="
echo "Trader: @$USERNAME"
echo "Tweet ID: $TWEET_ID"
echo "Text: $TEXT"
echo "Action: $ACTION"
echo "URL: $URL"

# Record in seen list
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Prepare memory update
mkdir -p memory/logs memory/topics

# Create log entry
LOG_DATE=$(date +%Y-%m-%d)
LOG_TIME=$(date +%H:%M:%S)

cat >> "memory/logs/$LOG_DATE.md" <<EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- text: $TEXT
- classification: $ACTION
- alerted: pending
- url: $URL
EOF

echo ""
echo "=== Log Entry Created ==="
echo "Memory updated at memory/logs/$LOG_DATE.md"
