#!/bin/bash

# X Trader Monitor - Real-time classification and alerting
# Today: 2026-07-28

var="eyJpZCI6IjIwODIxNTM2MjI3MTcwNDMwNDkiLCJ1c2VybmFtZSI6IlN0b2lpaWMiLCJ0ZXh0IjoibW9yZSBvZiB0aGUgc2xvdyBib3JpbmcgcGFydCBmb3IgdGhlIG5leHQgbW9udGggb3IgdHdvLlxuXG5jaG9wLiIsImNyZWF0ZWRfYXQiOiJUdWUgSnVsIDI4IDE3OjE4OjAyICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1N0b2lpaWMvc3RhdHVzLzIwODIxNTM2MjI3MTcwNDMwNDkiLCJtZWRpYSI6W119"

# Step 1 - Decode the event
if [ -z "$var" ]; then
  echo "X_TRADER_NO_EVENT"
  exit 0
fi

EVENT_JSON=$(printf '%s' "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: missing text"
  exit 1
fi

echo "=== Event Decoded ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo ""
echo "Text:"
echo "$TEXT"
echo ""
