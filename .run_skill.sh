#!/bin/bash

# Base64-encoded event data
VAR_B64="eyJpZCI6IjIxMDA2MzMzNDk0NDY1Nzg0NTAiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJLZWVwIHdvcmtpbmcgYm95cyEgXG5cbk5lZWQgdGhhdCBzdWIgMTAwIHdlZWtseSBjbG9zZSIsImNyZWF0ZWRfYXQiOiJUaHUgU2VwIDE3IDE3OjA5OjUzICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1dpbGRfUmFuZG9tbmVzcy9zdGF0dXMvMjEwMDYzMzM0OTQ0NjU3ODQ1MCIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9hbXBsaWZ5X3ZpZGVvX3RodW1iLzIxMDA2MzE1MDM1ODM0ODE4NTYvaW1nL1Zicnl0VFd2TkVDQkhfWnguanBnIl19"

# Step 1: Decode the event
EVENT_JSON=$(echo "$VAR_B64" | base64 -d 2>/dev/null)

# Validate the event
if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode"
  exit 1
fi

# Extract fields
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at' 2>/dev/null)

echo "=== EVENT DECODED ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo ""
echo "=== FULL JSON ==="
echo "$EVENT_JSON" | jq .
