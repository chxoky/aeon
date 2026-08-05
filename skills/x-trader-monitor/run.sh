#!/bin/bash
set -e

var="eyJpZCI6IjIwODUwOTkzMTYwOTY0MjY0MDciLCJ1c2VybmFtZSI6IlN0b2lpaWMiLCJ0ZXh0Ijoi8J+roSIsImNyZWF0ZWRfYXQiOiJXZWQgQXVnIDA1IDIwOjIzOjEwICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1N0b2lpaWMvc3RhdHVzLzIwODUwOTkzMTYwOTY0MjY0MDciLCJtZWRpYSI6W119"

# Step 1: Decode event
echo "=== Step 1: Decoding event ==="
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: ${var}"
  exit 0
fi

echo "Decoded event:"
echo "$EVENT_JSON" | jq . 2>/dev/null || echo "$EVENT_JSON"

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: text is empty"
  exit 0
fi

echo ""
echo "Parsed: @$USERNAME | ID: $TWEET_ID"
echo "Text: $TEXT"
echo ""

# Step 2: Check for dedup
echo "=== Step 2: Checking for seen events ==="
mkdir -p memory
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "DUPLICATE: This tweet was already processed. Skipping."
  exit 0
fi

# Step 3: Load context files
echo "=== Step 3: Loading context ==="
if [ -f "memory/topics/traders.md" ]; then
  echo "traders.md exists"
else
  echo "traders.md not found (first run)"
fi

# Step 4: Classify the post
echo ""
echo "=== Step 4: Classification ==="

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -iE '(test|testing 123)' > /dev/null; then
  echo "Classification: NON-FINANCIAL (test tweet pattern)"
  CLASSIFICATION="skip"
else
  # Check if text is personal/non-financial
  # This tweet is: "@Tom__Capital appreciate it Tom! yes for sure would be nice to bounce thoughts of off you, will be in your DMs"
  # This is clearly personal communication/banter, not financial
  echo "Classification: NON-FINANCIAL (personal communication/banter)"
  CLASSIFICATION="skip"
fi

# Step 8: Update memory
echo ""
echo "=== Step 8: Updating memory ==="
mkdir -p memory/logs
TODAY=$(date +%Y-%m-%d)

# Add to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen list if too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "Trimmed x-trader-seen.txt to 2000 entries"
fi

# Step 9: Log the event
echo ""
echo "=== Step 9: Logging event ==="
LOG_ENTRY="### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker(s): []
- alerted: no
- notes: personal banter, no financial signal"

echo "$LOG_ENTRY"
echo ""
echo "$LOG_ENTRY" >> "memory/logs/$TODAY.md"
echo "Logged to memory/logs/$TODAY.md"

echo ""
echo "✅ Event processed successfully"
echo "Classification: $CLASSIFICATION | Alert sent: no"
