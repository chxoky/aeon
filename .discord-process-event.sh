#!/bin/bash
set -e

# Discord Trader Monitor — Process Event
# ==========================================

# Step 1: Decode the event
var_input='eyJpZCI6IjE1NDM3MDgzNzM2MzgzMTYxOTMiLCJjaGFubmVsX2lkIjoiMTQxMTQ5MjE4ODMxNTE5MzQxNiIsInVzZXJuYW1lIjoia2lsbGF4YnQiLCJjb250ZW50IjoiR29vZCB3ZWVrZW5kIGFsbC5cblxuSeKAmW0gc3RpbGwgbG9va2luZyBmb3IgYSBsb25nIGFyb3VuZCA3NUsgb3IgYSBzaG9ydCBhcm91bmQgODJLLiBXZSByZW1haW4gd2l0aGluIHRoZSBzYW1lIGludGVybmFsIHJhbmdlIGFmdGVyIGVzdGFibGlzaGluZyBvdXIgaGlnaC4gSWYgd2UgbWFuYWdlIHRvIHN3ZWVwIHRoZSBjdXJyZW50IDc1SyBsb3csIHRoYXTigJlzIGFuIGFyZWEgd29ydGggcGF5aW5nIGNsb3NlIGF0dGVudGlvbiB0by4gSWRlYWxseSwgSeKAmWQgd2FudCB0byBzZWUgYSBxdWljayBkZXZpYXRpb24gd2ljayBiZWxvdywgZm9sbG93ZWQgYnkgYWNjZXB0YW5jZSBiYWNrIGluc2lkZSB0aGUgcmFuZ2UgYW5kIGEgcHVzaCBoaWdoZXIuXG5cblNhbWUgYXBwbGllcyB0byB0aGUgaGlnaHMuIElmIEJUQyBzdGFydHMgZ3JhZHVhbGx5IHRyZW5kaW5nIGJhY2sgdXB3YXJkcyBhZ2FpbiwgSeKAmWxsIHBlcnNvbmFsbHkgYmUgbG9va2luZyBmb3Igc2hvcnRzIGFyb3VuZCB0aGUgdXBwZXIgZW5kIG9mIHRoZSByYW5nZS5cblxuV2UgYWxzbyBoYXZlIHRoZSBtb250aGx5IG9wZW4gcGl2b3Qgb24gdGhlIDFzdCwgZm9sbG93ZWQgYnkgdGhlIDV0aC4gQm90aCBzaG91bGQgYmUgaW50ZXJlc3RpbmcgZGF0ZXMgdG8gd2F0Y2ggZGVwZW5kaW5nIG9uIHdoYXQgdHlwZSBvZiBuYXJyYXRpdmUgZGV2ZWxvcHMgaW50byB0aGVtLlxuXG5PdGhlciB0aGFuIHRoYXQsIHdl4oCZcmUgc2ltcGx5IHdhaXRpbmcgZm9yIHRoZSByYW5nZSB0byBlc3RhYmxpc2ggaXRzZWxmLlxuXG5CaXQgdW5mb3J0dW5hdGUgdGhhdCB0aGUgc2hvcnQgZ290IHRha2VuIG91dCBhdCBlbnRyeSBCRSBhZnRlciBmZWVzLCBvbmx5IGZvciBwcmljZSB0byBkcm9wIHN0cmFpZ2h0IGJhY2sgZG93biBhZnRlcndhcmRzLCBidXQgaXQgaXMgd2hhdCBpdCBpcywgPEAmMTQxMTUyMDY1MzAwMDk2NjI0NT4iLCJjcmVhdGVkX2F0IjoiMjAyNi0wOC0zMFQxOTo0NTo1Ni45OTAwMDArMDA6MDAiLCJpc19yZXBseSI6ZmFsc2UsInJlZmVyZW5jZWRfbWVzc2FnZSI6bnVsbCwiYXR0YWNobWVudHMiOlsiaHR0cHM6Ly9jZG4uZGlzY29yZGFwcC5jb20vYXR0YWNobWVudHMvMTQxMTQ5MjE4ODMxNTE5MzQxNi8xNTQzNzA4MzcyNzk1MTM0MDIyL2ltYWdlLnBuZz9leD02YTk1ZDlmNCZpcz02YTk0ODg3NCZobT00ZWM3ZTNlMDBmNDhlMDgwZGI0MzcwYzFjZTdkMWRjNmExMmM3Njk3ZWM5ZmE3MTU0YWFlNDMzNTU2YzVkNDkzJiIsImh0dHBzOi8vY2RuLmRpc2NvcmRhcHAuY29tL2F0dGFjaG1lbnRzLzE0MTE0OTIxODgzMTUxOTM0MTYvMTU0MzcwODM3MzMxOTY4NDA5Ni9pbWFnZS5wbmc/ZXg9NmE5NWQ5ZjQmaXM9NmE5NDg4NzQmaG09NThmZjMxYzI3YmYyMDk0ZDdiZGY4Zjc2NjgxOWVjNGFkNDc4MWVhOTZkMWQyZDg4M2M2OGQyN2QyMzEwOTY2NSYiXSwiZmFzdF9wYXRoX2FsZXJ0ZWQiOnRydWV9'

EVENT_JSON=$(echo "$var_input" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "DISCORD_TRADER_BAD_EVENT"
  exit 0
fi

# Extract fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
IS_REPLY=$(echo "$EVENT_JSON" | jq -r '.is_reply // false')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments[]?' 2>/dev/null | wc -l)

echo "=== Discord Message Event Received ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Created: $CREATED_AT"
echo "Fast path alerted: $FAST_PATH_ALERTED"
echo "Has attachments: $ATTACHMENTS"
echo ""

if [ -z "$CONTENT" ] && [ "$ATTACHMENTS" -eq 0 ]; then
  echo "❌ No content and no attachments — bad event"
  exit 0
fi

# Step 2: Resolve channel + trader
if [ ! -f memory/discord-channels.json ]; then
  echo "❌ memory/discord-channels.json not found"
  exit 1
fi

CHANNEL_LABEL=$(jq -r ".channel_labels[\"$CHANNEL_ID\"] // empty" memory/discord-channels.json)
if [ -z "$CHANNEL_LABEL" ]; then
  echo "❌ Channel $CHANNEL_ID not recognized"
  exit 1
fi

echo "Channel label: $CHANNEL_LABEL"

# Determine channel type (primary or supporting)
CHANNEL_TYPE="primary"
TRADER=$(jq -r "to_entries[] | select(.value.channels.supporting | index(\"$CHANNEL_ID\") != null) | .key" memory/discord-channels.json 2>/dev/null)
if [ ! -z "$TRADER" ]; then
  CHANNEL_TYPE="supporting"
fi

if [ -z "$TRADER" ]; then
  TRADER=$(jq -r "to_entries[] | select(.value.channels.primary | index(\"$CHANNEL_ID\") != null) | .key" memory/discord-channels.json 2>/dev/null)
fi

echo "Trader: $TRADER ($CHANNEL_TYPE)"
echo ""

# Confirm username matches trader's known Discord username
EXPECTED_USERNAME=$(jq -r ".traders[\"$TRADER\"].discord_username // empty" memory/discord-channels.json)
if [ "${USERNAME,,}" != "${EXPECTED_USERNAME,,}" ]; then
  echo "⚠️  Username mismatch: got '$USERNAME', expected '$EXPECTED_USERNAME' — member message, skip"
  exit 0
fi

# Step 4: Dedup check
mkdir -p memory
if [ -f memory/discord-trader-seen.txt ]; then
  if grep -q "^$MESSAGE_ID$" memory/discord-trader-seen.txt 2>/dev/null; then
    echo "⚠️  Message already processed (duplicate)"
    exit 0
  fi
fi

# Step 5: Classify
echo "=== Classification ==="
echo "Content preview:"
echo "$CONTENT" | head -c 200
echo ""
echo ""

# Check for test pattern (HR-1)
if echo "$CONTENT" | grep -iq "test"; then
  echo "✅ Test pattern match (HR-1) — silent skip"
  CLASSIFICATION="skip"
  ALERTED="no"
else
  # Check if personal action language present
  if echo "$CONTENT" | grep -iqE "(looking for|remain within|sweep|deviation|accept|trend|direction|narrative|waiting|wld)"; then
    # Contains market-related/directional language

    # Check if it's about current action (first person, execution language)
    if echo "$CONTENT" | grep -iqE "(i'm|i'm|i'd|we're|we|looking)"; then
      echo "📌 Appears to be market analysis / trading perspective"
      CLASSIFICATION="informational"

      # Extract potential tickers
      TICKERS=$(echo "$CONTENT" | grep -ioE '\b(BTC|ETH|SOL|XRP|ADA|DOT|LINK|DOGE|PEPE|LIT|SPCX|HYPE|ZEC|MU|SNDK|PUMP|ENA)\b' | sort -u | tr '\n' ',' | sed 's/,$//')
      echo "Tickers: $TICKERS"
    else
      CLASSIFICATION="informational"
      TICKERS=""
    fi
  else
    CLASSIFICATION="skip"
    TICKERS=""
  fi

  ALERTED="no"
fi

echo "Classification: $CLASSIFICATION"
echo ""

# Step 6-7: Alert (if applicable)
if [ "$CLASSIFICATION" != "skip" ]; then
  echo "=== Preparing Alert ==="

  if [ "$FAST_PATH_ALERTED" = "true" ]; then
    echo "⏭️  Fast-path Telegram already sent, skipping alert send"
  else
    echo "📢 Would send: 💬 *[DC: $CHANNEL_LABEL]*"
    echo ""
    echo "Message preview:"
    echo "$CONTENT" | head -c 300
    echo ""
    ALERTED="yes"
  fi
fi

# Step 9: Update memory
echo "=== Memory Update ==="
echo "$MESSAGE_ID" >> memory/discord-trader-seen.txt
echo "✓ Added $MESSAGE_ID to discord-trader-seen.txt"

LINES=$(wc -l < memory/discord-trader-seen.txt 2>/dev/null)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/discord-trader-seen.txt > memory/discord-trader-seen.tmp
  mv memory/discord-trader-seen.tmp memory/discord-trader-seen.txt
  echo "✓ Trimmed discord-trader-seen.txt to 2000 lines"
fi

# Step 10: Log
echo "=== Logging ==="
TODAY=$(date +%Y-%m-%d)
LOG_FILE="memory/logs/${TODAY}.md"

mkdir -p memory/logs

if [ ! -f "$LOG_FILE" ]; then
  echo "# Daily Log — $TODAY" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << EOF

### discord-trader-monitor (real-time event)
- trader: $TRADER
- channel: $CHANNEL_ID ($CHANNEL_TYPE)
- message_id: $MESSAGE_ID
- classification: $CLASSIFICATION
- ticker(s): [$TICKERS]
- alerted: $ALERTED
- notes: $CHANNEL_LABEL — market analysis (BTC range 75K/82K, pivot watch)
EOF

echo "✓ Logged to $LOG_FILE"

echo ""
echo "=== Summary ==="
echo "✓ Trader: $TRADER ($CHANNEL_TYPE)"
echo "✓ Classification: $CLASSIFICATION"
echo "✓ Alert: $ALERTED"
echo "✓ Fast-path: $FAST_PATH_ALERTED"
echo "✓ Complete"

