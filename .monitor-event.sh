#!/bin/bash
var="eyJpZCI6IjIwODA1MDg2NjAyNzk1NTQxODMiLCJ1c2VybmFtZSI6IlN0b2lpaWMiLCJ0ZXh0IjoiQEpvcmRpQ2hhcnRzIGl0cyBqdXN0IHNwb3QgY2IsIGJpbmFuY2UgYW5kIGtyYWtlbiIsImNyZWF0ZWRfYXQiOiJGcmkgSnVsIDI0IDA0OjIxOjMzICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1N0b2lpaWMvc3RhdHVzLzIwODA1MDg2NjAyNzk1NTQxODMiLCJtZWRpYSI6W119"
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode"
  exit 1
fi
echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq .
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)
echo ""
echo "=== PARSED FIELDS ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media: $MEDIA"
