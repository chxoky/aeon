#!/bin/bash
set -e

# Discord trader monitor execution
TODAY="2026-08-04"
EVENT='{"id":"1534310334456664105","channel_id":"1472153627324842057","username":"heartcanhodl","content":"","created_at":"2026-08-04T21:21:29.842000+00:00","is_reply":true,"referenced_message":{"username":"heartcanhodl","content":"I am their worst counterparty"},"attachments":["https://cdn.discordapp.com/attachments/1472153627324842057/1534310334339219657/IMG_20260805_025114.jpg?ex=6a73a959&is=6a7257d9&hm=7ec0b05b728cc102840d698782c4c9f99609f8786999aad061a67a0ea1021021&"],"fast_path_alerted":false}'

# Step 1: Validate event
MESSAGE_ID=$(echo "$EVENT" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT" | jq -r '.username')
CONTENT=$(echo "$EVENT" | jq -r '.content // empty')
IS_REPLY=$(echo "$EVENT" | jq -r '.is_reply')
FAST_PATH=$(echo "$EVENT" | jq -r '.fast_path_alerted')
REFERENCED=$(echo "$EVENT" | jq -r '.referenced_message.content // empty')
HAS_ATTACHMENTS=$(echo "$EVENT" | jq '.attachments | length')

echo "=== STEP 1: EVENT VALIDATION ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Content empty: $([ -z "$CONTENT" ] && echo 'yes' || echo 'no')"
echo "Attachments: $HAS_ATTACHMENTS"
echo "Is Reply: $IS_REPLY"
echo "Referenced: $REFERENCED"
echo "Fast Path: $FAST_PATH"

# Validation: content must not be empty OR must have attachments
if [ -z "$CONTENT" ] && [ "$HAS_ATTACHMENTS" -eq 0 ]; then
  echo "❌ DISCORD_TRADER_BAD_EVENT: empty content with no attachments"
  exit 0
fi

# Step 2: Resolve channel + trader
echo ""
echo "=== STEP 2: CHANNEL RESOLUTION ==="
CHANNELS=$(cat memory/discord-channels.json)
CHANNEL_LABEL=$(echo "$CHANNELS" | jq -r ".channel_labels[\"$CHANNEL_ID\"] // \"UNKNOWN\"")
TRADER=$(echo "$CHANNELS" | jq -r ".traders[] | select(.channels.primary[]? == \"$CHANNEL_ID\" or .channels.supporting[]? == \"$CHANNEL_ID\") | .discord_username" | head -1)

echo "Channel Label: $CHANNEL_LABEL"
echo "Trader Discord Username: $TRADER"

# Confirm username matches
if [ "$USERNAME" != "heartcanhodl" ]; then
  echo "❌ Username mismatch - skipping (not the trader)"
  exit 0
fi

# Step 3: Check if already seen
echo ""
echo "=== STEP 3: DEDUP CHECK ==="
if grep -q "^$MESSAGE_ID$" memory/discord-trader-seen.txt 2>/dev/null; then
  echo "⚠️  Message already seen - skipping"
  exit 0
fi

# Step 5: Classify the message
echo ""
echo "=== STEP 5: CLASSIFICATION ==="
echo "Message type: Image-only reply (no text content)"
echo "Self-reply to: 'I am their worst counterparty'"
echo "Cannot interpret without viewing image"
echo "Classification: AMBIGUOUS (HR-2 protocol)"

# This message is cryptic/image-only, so we need to ask Kyle
CLASSIFICATION="ambiguous"
ALERTED="no"

echo ""
echo "=== CALIBRATION ALERT (HR-2) ==="
ALERT_MSG="🔍 *Calibration — [DC: HCH — Free]*

Event: Self-reply to 'I am their worst counterparty'
HeartCanHodl: [image-only message, cannot interpret without context]

Unable to classify — what's your read?"

echo "$ALERT_MSG"

# Step 9: Update seen tracking
mkdir -p memory
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi

# Step 10: Log
echo ""
echo "=== STEP 10: LOGGING ==="
LOG_ENTRY="### discord-trader-monitor (real-time event)
- trader: heartcanhodl
- channel: $CHANNEL_ID (primary: HCH — Free)
- message_id: $MESSAGE_ID
- classification: $CLASSIFICATION
- ticker(s): []
- alerted: $ALERTED
- notes: image-only reply to self ('I am their worst counterparty'); ambiguous context"

echo "$LOG_ENTRY"

# Append to log
mkdir -p memory/logs
echo "" >> memory/logs/${TODAY}.md
echo "$LOG_ENTRY" >> memory/logs/${TODAY}.md

echo ""
echo "✅ Skill execution complete"
