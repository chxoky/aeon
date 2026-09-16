#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon

var="eyJpZCI6IjE1NDk3OTk0NjY5MzA5MzM4MTMiLCJjaGFubmVsX2lkIjoiMTQ3MjE1MzYyNzMyNDg0MjA1NyIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkZjIGNsdXNkdCAxNW0iLCJjcmVhdGVkX2F0IjoiMjAyNi0wOS0xNlQxNTowOTo0Ni43OTgwMDArMDA6MDAiLCJpc19yZXBseSI6ZmFsc2UsInJlZmVyZW5jZWRfbWVzc2FnZSI6bnVsbCwiYXR0YWNobWVudHMiOltdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9"

# Step 1: Decode the event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .
echo ""

# Extract fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')

echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"
echo ""

# Check if message was already seen
mkdir -p memory
if [ -f "memory/discord-trader-seen.txt" ] && grep -q "^$MESSAGE_ID$" memory/discord-trader-seen.txt; then
  echo "Message already processed: $MESSAGE_ID"
  exit 0
fi

# Record the message ID
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt

# Trim seen file if too large
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi

echo "Processing complete. Message recorded."
