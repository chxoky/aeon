#!/bin/bash
set -e

var="eyJpZCI6IjE1MzQ2Mzk2NjU5MDUyNzQ5ODAiLCJjaGFubmVsX2lkIjoiMTQ3MjE1MzYyNzMyNDg0MjA1NyIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkNhdWdodCBoaW0hIPCfjqMiLCJjcmVhdGVkX2F0IjoiMjAyNi0wOC0wNVQxOToxMDowOC41NzgwMDArMDA6MDAiLCJpc19yZXBseSI6dHJ1ZSwicmVmZXJlbmNlZF9tZXNzYWdlIjp7InVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IkdvaW5nIHRvIGh1bnQgdGhpcyJ9LCJhdHRhY2htZW50cyI6WyJodHRwczovL2Nkbi5kaXNjb3JkYXBwLmNvbS9hdHRhY2htZW50cy8xNDcyMTUzNjI3MzI0ODQyMDU3LzE1MzQ2Mzk2NjU1MzYxNzIwODIvU2NyZWVuc2hvdF8yMDI2LTA4LTA2LTAwLTM5LTM1LTY0X2U0NDI0MjU4YzhiODY0OWY2ZTY3ZDI4M2E1MGEyY2JjLmpwZz9leD02YTc0ZGMxMCZpcz02YTczOGE5MCZobT0yNzlhMGVmNDg1YTIyYWI1MGRjN2FmMDExN2NkOTdkOTdkNmU0ZGRiNDdkOWFiNDQzYzRjYTY5NjM5YzRjNWY3YzMwJiJdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9"

today="2026-08-05"

# Step 1: Decode event
echo "=== Step 1: Decoding event ==="
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT: Failed to decode"
  exit 1
fi

echo "Raw event:"
echo "$EVENT_JSON" | jq .

# Extract fields
id=$(echo "$EVENT_JSON" | jq -r '.id // empty')
channel_id=$(echo "$EVENT_JSON" | jq -r '.channel_id // empty')
username=$(echo "$EVENT_JSON" | jq -r '.username // empty')
content=$(echo "$EVENT_JSON" | jq -r '.content // empty')
created_at=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
is_reply=$(echo "$EVENT_JSON" | jq -r '.is_reply // false')
fast_path_alerted=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')
attachments=$(echo "$EVENT_JSON" | jq -r '.attachments[]? // empty' | head -1)
ref_username=$(echo "$EVENT_JSON" | jq -r '.referenced_message.username // empty')
ref_content=$(echo "$EVENT_JSON" | jq -r '.referenced_message.content // empty')

echo ""
echo "=== Parsed Fields ==="
echo "ID: $id"
echo "Channel: $channel_id"
echo "Username: $username"
echo "Content: $content"
echo "Created: $created_at"
echo "Is Reply: $is_reply"
echo "Fast Path Alerted: $fast_path_alerted"
echo "Has Attachment: $([ -n "$attachments" ] && echo "Yes" || echo "No")"
if [ "$is_reply" = "true" ]; then
  echo "Reply To: $ref_username - $ref_content"
fi

# Step 2: Check for duplicates
echo ""
echo "=== Step 2: Check Duplicates ==="
mkdir -p memory
if grep -q "^$id$" memory/discord-trader-seen.txt 2>/dev/null; then
  echo "Message already processed. Stopping."
  exit 0
fi
echo "Message is new."

# Step 3: Check channel mapping
echo ""
echo "=== Step 3: Load Channel Configuration ==="
if [ -f memory/discord-channels.json ]; then
  channel_info=$(jq -r ".channels[\"$channel_id\"] // empty" memory/discord-channels.json)
  channel_label=$(jq -r ".labels[\"$channel_id\"] // \"Unknown\"" memory/discord-channels.json)
  echo "Channel Label: $channel_label"
  echo "Channel Info: $channel_info"
else
  echo "WARNING: memory/discord-channels.json not found"
  channel_label="HCH-Channel"
fi

# Step 4: Fast path check
echo ""
echo "=== Step 4: Fast Path Check ==="
if [ "$fast_path_alerted" = "true" ]; then
  echo "Message already alerted via fast path. Skipping Telegram send."
  skip_telegram=true
else
  echo "Processing full flow with alerting enabled."
  skip_telegram=false
fi

# Step 5: Message classification
echo ""
echo "=== Step 5: Message Classification ==="
# "Caught him! 🎯" in reply to "Going to hunt this" - context suggests possible trade execution

if [[ "$content" == *"test"* ]] || [[ "$content" == *"testing"* ]]; then
  classification="skip"
  echo "Classification: Test message (skip)"
elif echo "$content" | grep -iE "(caught|hunt|found|bagged)" > /dev/null; then
  echo "Classification: Possible trade execution signal"
  if [ "$is_reply" = "true" ]; then
    echo "Context: Reply to '$ref_content'"
    echo "This appears to be a execution confirmation of a hunting/shorting plan"
    classification="trade-execution-confirmation"
  else
    classification="informational"
  fi
else
  classification="informational"
fi

# Step 6: Alert decision
echo ""
echo "=== Step 6: Alert Decision ==="
should_alert=true
alert_type="informational"

if [ "$classification" = "skip" ]; then
  should_alert=false
  echo "Skip: No alert needed"
elif [ "$classification" = "trade-execution-confirmation" ]; then
  alert_type="execution"
  echo "Alerting: Possible trade execution confirmation"
else
  echo "Alerting: Informational"
fi

# Step 7: Generate alert (if needed and not fast-path alerted)
echo ""
echo "=== Step 7: Prepare Alert ==="
if [ "$should_alert" = "true" ] && [ "$skip_telegram" = "false" ]; then
  alert_body="💬 *[DC: $channel_label]*

$content"

  if [ "$is_reply" = "true" ] && [ -n "$ref_content" ]; then
    ref_trim=$(echo "$ref_content" | cut -c1-150)
    alert_body="↩️ _Member: \"$ref_trim\"_

💬 *[DC: $channel_label]*

$content"
  fi

  echo "Alert prepared:"
  echo "$alert_body"

  # Simulate notify (in real execution, this would send)
  echo ""
  echo "Would send to Telegram:"
  echo "$alert_body"
else
  echo "No alert to send (skip=$skip_telegram or should_alert=$should_alert)"
fi

# Step 8: Update memory
echo ""
echo "=== Step 8: Update Memory ==="
echo "$id" >> memory/discord-trader-seen.txt

# Trim if needed
LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp && mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
fi

echo "Message ID saved to discord-trader-seen.txt"

# Step 9: Log the event
echo ""
echo "=== Step 9: Logging ==="
mkdir -p memory/logs

log_entry="### discord-trader-monitor (real-time event)
- trader: $username
- channel: $channel_id ($channel_label)
- message_id: $id
- classification: $classification
- is_reply: $is_reply
- content_preview: ${content:0:80}...
- alerted: $([ "$should_alert" = "true" ] && echo "yes" || echo "no")
- fast_path_alerted: $fast_path_alerted
"

echo "$log_entry"
echo "$log_entry" >> memory/logs/${today}.md

echo ""
echo "=== Execution Complete ==="
