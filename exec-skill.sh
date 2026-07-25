#!/bin/bash
set -e

# Set the var with the provided event data
var="eyJpZCI6IjIwODA5Mjg5NTkzNzAyOTc4MjgiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGNyeXB0b2xlb24gRG9u4oCZdCBrbm93IiwiY3JlYXRlZF9hdCI6IlNhdCBKdWwgMjUgMDg6MTE6NDAgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vc3dhcm1pc3Rlci9zdGF0dXMvMjA4MDkyODk1OTM3MDI5NzgyOCIsIm1lZGlhIjpbXX0="

cd /home/runner/work/aeon/aeon

# Step 1: Decode event
echo "=== Step 1: Decode event ==="
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media | length')

echo ""
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media count: $MEDIA"

# Check for duplicate
echo ""
echo "=== Checking for duplicates ==="
mkdir -p memory
if [ -f memory/x-trader-seen.txt ] && grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "DUPLICATE: This tweet was already processed. Exiting."
  exit 0
else
  echo "New tweet, proceeding..."
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
fi

# Step 2: Load context
echo ""
echo "=== Step 2: Load context ==="
if [ -f "memory/topics/traders.md" ]; then
  echo "Found traders.md"
  grep -A 5 "^## @$USERNAME" memory/topics/traders.md 2>/dev/null || echo "No existing context for @$USERNAME"
fi

# Step 3: Cross-platform dedup (only for Chase, Killa, HCH)
echo ""
echo "=== Step 3: Cross-platform dedup ==="
DUAL_PLATFORM=("Crypto_Chase" "KillaXBT" "HeartCanHodl")
IS_DUAL=0
for trader in "${DUAL_PLATFORM[@]}"; do
  if [ "$USERNAME" = "$trader" ]; then
    IS_DUAL=1
    break
  fi
done
echo "Is dual-platform trader: $IS_DUAL"

# Step 4: Classify
echo ""
echo "=== Step 4: Classify ==="

# HR-1: Test tweets
if echo "$TEXT" | grep -iE 'test|testing' >/dev/null; then
  echo "Classification: NON-FINANCIAL (test tweet) - SKIP"
  exit 0
fi

# Check financial keywords
HAS_FINANCIAL=0
if echo "$TEXT" | grep -iE "(long|short|bull|bear|crypto|btc|eth|sell|buy|price|chart|position|entry|target|filled|cancelled|added|scaled)" >/dev/null; then
  HAS_FINANCIAL=1
fi

echo "Has financial keywords: $HAS_FINANCIAL"

# Check if it's personal action
HAS_ACTION=0
if echo "$TEXT" | grep -iE "just (longed|shorted|bought|sold|added|took profit|cancelled|filled|placed)" >/dev/null; then
  HAS_ACTION=1
  echo "Classification: PERSONAL TRADE ACTION DETECTED"
else
  echo "Classification: OPINION/INFORMATIONAL"
fi

# Step 5-6: Determine alert type
echo ""
echo "=== Classification Result ==="

if [ $HAS_FINANCIAL -eq 0 ]; then
  CLASSIFICATION="skip"
  echo "Result: NON-FINANCIAL - SKIP (no financial keywords)"
  SHOULD_ALERT=0
elif [ $HAS_ACTION -eq 1 ]; then
  CLASSIFICATION="trade-action"
  echo "Result: TRADE ACTION - ALERT"
  SHOULD_ALERT=1
else
  CLASSIFICATION="informational"
  echo "Result: INFORMATIONAL - EVALUATE"
  if echo "$TEXT" | grep -iE "(@)" >/dev/null; then
    echo "Note: This is a reply/mention without clear action"
    CLASSIFICATION="ambiguous"
    SHOULD_ALERT=1
  else
    SHOULD_ALERT=0
  fi
fi

echo "Text: \"$TEXT\""
echo "Final classification: $CLASSIFICATION"
echo "Should alert: $SHOULD_ALERT"

# Step 8: Update memory
echo ""
echo "=== Step 8: Update memory ==="
mkdir -p memory/topics memory/logs
TODAY=$(date +%Y-%m-%d)

# Append to traders.md
if [ ! -f "memory/topics/traders.md" ]; then
  echo "# Traders Memory" > "memory/topics/traders.md"
fi

# Check if trader section exists, if not create it
if ! grep -q "^## @$USERNAME" memory/topics/traders.md; then
  echo "" >> memory/topics/traders.md
  echo "## @$USERNAME" >> memory/topics/traders.md
  echo "**Current open positions:** TBD" >> memory/topics/traders.md
  echo "**Recent thesis:** TBD" >> memory/topics/traders.md
  echo "**Calibration:** First contact" >> memory/topics/traders.md
  echo "**Last seen:** $CREATED_AT" >> memory/topics/traders.md
  echo "**Events (rolling):**" >> memory/topics/traders.md
fi

# Append event line
if [ "$CLASSIFICATION" != "skip" ]; then
  echo "  - $(date -d "$CREATED_AT" '+%b %d %H:%MZ' 2>/dev/null || echo "Jul 25 08:11Z") — $CLASSIFICATION: $(echo "$TEXT" | cut -c1-30)... [$TWEET_ID]" >> memory/topics/traders.md
fi

# Step 9: Log entry
touch "memory/logs/$TODAY.md"
echo "" >> "memory/logs/$TODAY.md"
echo "### x-trader-monitor (real-time event)" >> "memory/logs/$TODAY.md"
echo "- trader: @$USERNAME" >> "memory/logs/$TODAY.md"
echo "- tweet_id: $TWEET_ID" >> "memory/logs/$TODAY.md"
echo "- classification: $CLASSIFICATION" >> "memory/logs/$TODAY.md"
echo "- ticker(s): [none]" >> "memory/logs/$TODAY.md"
echo "- alerted: $([ $SHOULD_ALERT -eq 1 ] && echo "yes" || echo "no")" >> "memory/logs/$TODAY.md"
echo "- text: $TEXT" >> "memory/logs/$TODAY.md"
echo "- url: $URL" >> "memory/logs/$TODAY.md"

echo "Memory updated."
echo ""

# Step 10: Alert
echo "=== Step 10: Alert Decision ==="
if [ $SHOULD_ALERT -eq 1 ] && [ "$CLASSIFICATION" = "ambiguous" ]; then
  echo "ALERT: CALIBRATION NEEDED"
  echo ""
  echo "🔍 *Calibration — @$USERNAME*"
  echo ""
  echo "Text: \"$TEXT\""
  echo ""
  echo "Unable to classify - appears to be a reply without clear context. What's your read?"
  echo ""
  echo "[View post]($URL)"
elif [ $SHOULD_ALERT -eq 1 ] && [ "$CLASSIFICATION" = "trade-action" ]; then
  echo "ALERT: TRADE SIGNAL"
  echo ""
  echo "🚨 *Trade Signal — @$USERNAME*"
  echo ""
  echo "$TEXT"
  echo ""
  echo "[View post]($URL)"
elif [ "$CLASSIFICATION" = "skip" ]; then
  echo "NO ALERT: Non-financial content - skipped silently"
else
  echo "NO ALERT: Content logged to memory"
fi

echo ""
echo "=== Summary ==="
echo "Event processed for @$USERNAME"
echo "Classification: $CLASSIFICATION"
echo "Tweet ID: $TWEET_ID"
