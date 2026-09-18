#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon

# Decode the event
EVENT_JSON=$(cat << 'EOF' | base64 -d
eyJpZCI6IjE1NTA0MTAyODcwOTY1MzMwMjMiLCJjaGFubmVsX2lkIjoiMTAyMzYzODU3MzMxMzk2NjIxMiIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkxldCdzIHNlZSBzb2wgdG8gMTIwIHRha2VzIGhvdyBsb25nIiwiY3JlYXRlZF9hdCI6IjIwMjYtMDktMThUMDc6MzY6NTcuNjc0MDAwKzAwOjAwIiwiaXNfcmVwbHkiOmZhbHNlLCJyZWZlcmVuY2VkX21lc3NhZ2UiOm51bGwsImF0dGFjaG1lbnRzIjpbXSwiZmFzdF9wYXRoX2FsZXJ0ZWQiOnRydWV9
EOF
)

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted')

echo ""
echo "=== Extracted Fields ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Created At: $CREATED_AT"
echo "Is Reply: $IS_REPLY"
echo "Fast Path Alerted: $FAST_PATH_ALERTED"

# Step 1: Check if fast_path_alerted is true
if [ "$FAST_PATH_ALERTED" = "true" ]; then
  echo ""
  echo "=== Fast Path Already Alerted ==="
  echo "Skipping Telegram send. Processing for memory/classification only."
fi

# Check if message already seen
echo ""
echo "=== Checking Dedup ==="
if [ -f "memory/discord-trader-seen.txt" ]; then
  if grep -q "^$MESSAGE_ID$" memory/discord-trader-seen.txt; then
    echo "Message already processed. Stopping."
    exit 0
  fi
fi

# Record the message
mkdir -p memory
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt

# Check file size and prune if needed
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
  echo "Pruned discord-trader-seen.txt to 2000 lines"
fi

# Check for channel mapping
echo ""
echo "=== Channel Mapping ==="
if [ -f "memory/discord-channels.json" ]; then
  CHANNEL_INFO=$(jq ".channels[\"$CHANNEL_ID\"]" memory/discord-channels.json 2>/dev/null || echo "{}")
  echo "Channel info: $CHANNEL_INFO"
  CHANNEL_LABEL=$(echo "$CHANNEL_INFO" | jq -r '.label // empty')
  TRADER=$(echo "$CHANNEL_INFO" | jq -r '.trader // empty')
  CHANNEL_TYPE=$(echo "$CHANNEL_INFO" | jq -r '.type // empty')
  echo "Label: ${CHANNEL_LABEL:-unknown}"
  echo "Trader: ${TRADER:-unknown}"
  echo "Type: ${CHANNEL_TYPE:-unknown}"
else
  echo "memory/discord-channels.json not found"
fi

# Step 2: Verify username matches expected trader
if [ -n "$TRADER" ]; then
  if [ "${USERNAME,,}" != "${TRADER,,}" ]; then
    echo ""
    echo "=== Username Mismatch ==="
    echo "Message is from $USERNAME but channel $CHANNEL_ID is mapped to trader $TRADER"
    echo "Treating as member context message. Skip standalone alert."
  fi
fi

# Classification: "Let's see sol to 120 takes how long" - This is informational/speculation
echo ""
echo "=== Classification ==="
echo "Message content: '$CONTENT'"
echo "Classification: Informational - trader speculating on SOL price movement to 120"

# Log the event
TODAY=$(date +%Y-%m-%d)
mkdir -p memory/logs
cat >> "memory/logs/$TODAY.md" << LOGEOF

### discord-trader-monitor (real-time event)
- trader: $USERNAME
- channel: $CHANNEL_ID ($CHANNEL_TYPE)
- message_id: $MESSAGE_ID
- classification: informational
- ticker(s): [SOL]
- alerted: $([ "$FAST_PATH_ALERTED" = "true" ] && echo "fast-path" || echo "no")
- notes: Speculation on SOL reaching 120

LOGEOF

echo ""
echo "=== Logged to memory/logs/$TODAY.md ==="
echo "Task complete."
