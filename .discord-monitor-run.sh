#!/bin/bash
set -e

# Step 1: Decode the event
EVENT_JSON=$(echo "eyJpZCI6IjE1NDY5MTA3MDcyODk2OTQyMTEiLCJjaGFubmVsX2lkIjoiMTMzNjA4MjcxNjA2MzY5NDk2MiIsInVzZXJuYW1lIjoiY3J5cHRvX2NoYXNlIiwiY29udGVudCI6IjxAJjEyNDc5NDAyMzQ1NTgxNzc1MjE+IiwiY3JlYXRlZF9hdCI6IjIwMjYtMDktMDhUMTU6NTA6NTIuODI5MDAwKzAwOjAwIiwiaXNfcmVwbHkiOmZhbHNlLCJyZWZlcmVuY2VkX21lc3NhZ2UiOm51bGwsImF0dGFjaG1lbnRzIjpbXSwiZmFzdF9wYXRoX2FsZXJ0ZWQiOmZhbHNlfQ==" | base64 -d 2>/dev/null)

echo "=== Event Decoded ==="
echo "$EVENT_JSON" | jq '.'

# Extract fields
ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments | length')

echo ""
echo "=== Extracted Fields ==="
echo "ID: $ID"
echo "Channel: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"
echo "Attachments: $ATTACHMENTS"
