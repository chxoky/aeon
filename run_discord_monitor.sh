#!/bin/bash
set -e

var="eyJpZCI6IjE1MTk0MjMxMTE1NDY3OTgyMDAiLCJjaGFubmVsX2lkIjoiMTM5MzEzNzcwNTExMDg1MDc3MjgiLCJ1c2VybmFtZSI6ImhlYXJ0Y2FuaG9kbCIsImNvbnRlbnQiOiJEbyBvciBkaWUgdHJlbmQgY29udGludWF0aW9uIHpvbmUgZm9yIGh5cGUiLCJjcmVhdGVkX2F0IjoiMjAyNi0wNi0yNFQxOToyNDo1OS4zMDkwMDArMDA6MDAiLCJpc19yZXBseSI6ZmFsc2UsInJlZmVyZW5jZWRfbWVzc2FnZSI6bnVsbCwiYXR0YWNobWVudHMiOltdLCJmYXN0X3BhdGhfYWxlcnRlZCI6dHJ1ZX0="

# Step 1: Decode the event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: Unable to decode base64"
  exit 1
fi

echo "=== EVENT DECODED ==="
echo "$EVENT_JSON" | jq .

# Extract fields
ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted')

echo ""
echo "ID: $ID"
echo "CHANNEL_ID: $CHANNEL_ID"
echo "USERNAME: $USERNAME"
echo "CONTENT: $CONTENT"
echo "FAST_PATH_ALERTED: $FAST_PATH_ALERTED"
