#!/bin/bash
set -e

# Decode the Discord event
var="eyJpZCI6IjE1MTYwODUzNTcxNTcwMjc5OTIiLCJjaGFubmVsX2lkIjoiMTM0Mzk3MTI2NTk2MjA0OTU5NyIsInVzZXJuYW1lIjoiY3J5cHRvX2NoYXNlIiwiY29udGVudCI6IlNvbWV0aGluZyBsaWtlIHRoaXMgcGVyaGFwcyBidXQgSSBkb24ndCBrbm93IHlldCIsImNyZWF0ZWRfYXQiOiIyMDI2LTA2LTE1VDE0OjIxOjU2LjY1MDAwMCswMDowMCIsImlzX3JlcGx5Ijp0cnVlLCJyZWZlcmVuY2VkX21lc3NhZ2UiOnsidXNlcm5hbWUiOiJtcnJvYm90NjkyODA4IiwiY29udGVudCI6IldoYXQgZG8gd2UgdGhpbmsgb2YgU2lsdmVyPyBTZWVtcyBsaWtlIGl0IGhhcyBnaXZlbiBhIE1TQiBiZWZvcmUgc3dlZXBpbmcgdGhhdCBtYWpvciBsb3cuIEtpbmRhIGZvcm1lZCBhbiBlcXVhbCBsb3cgYmVsb3cifSwiYXR0YWNobWVudHMiOlsiaHR0cHM6Ly9jZG4uZGlzY29yZGFwcC5jb20vYXR0YWNobWVudHMvMTM0Mzk3MTI2NTk2MjA0OTU5Ny8xNTE2MDg1MzU2NjA3NTcwMTcyL2ltYWdlLnBuZz9leD02YTMyYWQ4NCZpcz02YTMxNWMwNCZobT05NDYxNzVmZTFjYjRkNGJmMjFjZTU0NTQ4NWViNWY0ZjdlYTgzOTkxYzVjYjVkOTY0NjAyMmU0Y2Y5YzAxZDZiJiJdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9"

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: failed to decode base64"
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
REFERENCED_MSG=$(echo "$EVENT_JSON" | jq -r '.referenced_message // empty')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments[]? // empty')

echo ""
echo "=== Step 1: Event Validation ==="
echo "ID: $ID"
echo "Channel: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"
echo "Referenced: $REFERENCED_MSG"
echo "Attachments: $ATTACHMENTS"

# Check if content is empty and no attachments
if [ -z "$CONTENT" ] && [ -z "$ATTACHMENTS" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: empty content and no attachments"
  exit 1
fi

echo ""
echo "✓ Event decoded and validated"
