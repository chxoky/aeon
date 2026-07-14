#!/bin/bash

var="eyJpZCI6IjE1MjAxNTY4NTEwODAwMDc4NjEiLCJjaGFubmVsX2lkIjoiMTI0NzkyNzc4NjY4MTc5NDYwMSIsInVzZXJuYW1lIjoiY3J5cHRvX2NoYXNlIiwiY29udGVudCI6IiIsImNyZWF0ZWRfYXQiOiIyMDI2LTA2LTI2VDIwOjAwOjM2LjQ0NjAwMCswMDowMCIsImlzX3JlcGx5IjpmYWxzZSwicmVmZXJlbmNlZF9tZXNzYWdlIjpudWxsLCJhdHRhY2htZW50cyI6WyJodHRwczovL2Nkbi5kaXNjb3JkYXBwLmNvbS9hdHRhY2htZW50cy8xMjQ3OTI3Nzg2NjgxNzk0NjAxLzE1MjAxNTY4NTA3OTUwNTczNjQvaW1hZ2UucG5nP2V4PTZhNDAyYmU0JmlzPTZhM2VkYTY0JmhtPTBhNWE5ZGUzYjljZDYxNDUyZDAyMGYwMjU3MjZiY2E1NWU0YmFlOWI0MmYwMDFlNGE3MzUxZjQxZGQ3ZDlkY2QmIl0sImZhc3RfcGF0aF9hbGVydGVkIjpmYWxzZX0="

# Decode and pretty-print
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: Failed to decode base64"
  exit 1
fi

echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq . || echo "$EVENT_JSON"

# Extract key fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply // false')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments // []')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')

echo ""
echo "=== PARSED FIELDS ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: '$CONTENT'"
echo "Created At: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Attachments: $ATTACHMENTS"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"

# Step 1 validation: content empty and no attachments?
if [ -z "$CONTENT" ] && [ "$ATTACHMENTS" = "[]" ]; then
  echo ""
  echo "DISCORD_TRADER_BAD_EVENT: Empty content and no attachments"
  exit 1
fi

if [ -z "$CONTENT" ] && [ "$ATTACHMENTS" != "[]" ]; then
  echo ""
  echo "✓ Message has attachments but no text — continuing with attachment processing"
fi
