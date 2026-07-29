#!/bin/bash

# Discord Trader Monitor - Step 1: Decode the event

var='eyJpZCI6IjE1MzIwNDYyMzIyNzE0NTQzNDkiLCJjaGFubmVsX2lkIjoiMTAyMzYzODU3MzMxMzk2NjIxMiIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkZjIGV0aCAxNW0gaHR0cHM6Ly94LmNvbS9pL3N0YXR1cy8yMDgyNDI0NTkzNjY3ODA5MzQ5IiwiY3JlYXRlZF9hdCI6IjIwMjYtMDctMjlUMTU6MjQ6NDUuODE2MDAwKzAwOjAwIiwiaXNfcmVwbHkiOmZhbHNlLCJyZWZlcmVuY2VkX21lc3NhZ2UiOm51bGwsImF0dGFjaG1lbnRzIjpbXSwiZmFzdF9wYXRoX2FsZXJ0ZWQiOnRydWV9'

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

echo "=== Decoded Event ==="
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
echo "=== Parsed Fields ==="
echo "ID: $ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created At: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"
