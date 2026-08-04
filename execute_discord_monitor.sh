#!/bin/bash
set -e

today="2026-08-04"
var='eyJpZCI6IjE1MzQyMjgzMDMwNzI5ODUzNjA3MjUyOCIsImNoYW5uZWxfaWQiOiIxMzM2MDgyNzE2MDYzNjk0OTYyIiwidXNlcm5hbWUiOiJjcnlwdG9fY2hhc2UiLCJjb250ZW50IjoiPEAmMTI0Nzk0MDIzNDU1ODE3NzUyMT4gODAlIGNsb3NlZCBvbiBTTkRLIiwiY3JlYXRlZF9hdCI6IjIwMjYtMDgtMDRUMTU6NTU6MzIuMDM2MDAwKzAwOjAwIiwiaXNfcmVwbHkiOmZhbHNlLCJyZWZlcmVuY2VkX21lc3NhZ2UiOm51bGwsImF0dGFjaG1lbnRzIjpbXSwiZmFzdF9wYXRoX2FsZXJ0ZWQiOnRydWV9'

# Step 1: Decode the event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: ${var}"
  exit 1
fi

echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq .

# Extract fields
ID=$(echo "$EVENT_JSON" | jq -r '.id // ""')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id // ""')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // ""')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content // ""')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // ""')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply // false')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')

echo ""
echo "=== EXTRACTED FIELDS ==="
echo "ID: $ID"
echo "CHANNEL_ID: $CHANNEL_ID"
echo "USERNAME: $USERNAME"
echo "CONTENT: $CONTENT"
echo "CREATED_AT: $CREATED_AT"
echo "IS_REPLY: $IS_REPLY"
echo "FAST_PATH_ALERTED: $FAST_PATH_ALERTED"

# Check if content is empty and no attachments
if [ -z "$CONTENT" ]; then
  ATTACHMENTS=$(echo "$EVENT_JSON" | jq '.attachments | length')
  if [ "$ATTACHMENTS" -eq 0 ]; then
    echo "DISCORD_TRADER_BAD_EVENT: empty content and no attachments"
    exit 1
  fi
fi

echo ""
echo "=== PROCESSING ==="
echo "Valid event decoded successfully"
