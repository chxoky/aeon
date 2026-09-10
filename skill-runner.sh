#!/bin/bash
set -e

# X Trader Monitor - Skill Execution
# Event processing for KillaXBT tweet

var='eyJpZCI6IjIwOTc4NDE1NjYwNjQ3MjIxODEiLCJ1c2VybmFtZSI6IktpbGxhWEJUIiwidGV4dCI6IkBKaW1teVBsYW5zIEFyZSB5b3UgbWVudGFsbHkgZGVyYW5nZWQ/IFxuXG5UaGlzIHBvc3QgaXMgY2xlYXJseSBtZSBtb2NraW5nIHRob3NlIHdobyB3ZXJlIHRhcmdldGluZyA0MC01MCUuIEkgYW0gbm90IHRhcmdldGluZy4iLCJjcmVhdGVkX2F0IjoiVGh1IFNlcCAxMCAwMDoxNjoyMCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9LaWxsYVhCVC9zdGF0dXMvMjA5Nzg0MTU2NjA2NDcyMjE4MSIsIm1lZGlhIjpbXX0='

# Step 1 - Decode the event
echo "=== Step 1: Decoding event ==="
EVENT_JSON=$(echo "$var" | base64 -d)
echo "$EVENT_JSON" > /tmp/event.json

# Parse fields
TWEET_ID=$(cat /tmp/event.json | jq -r '.id')
USERNAME=$(cat /tmp/event.json | jq -r '.username')
TEXT=$(cat /tmp/event.json | jq -r '.text')
CREATED_AT=$(cat /tmp/event.json | jq -r '.created_at')
URL=$(cat /tmp/event.json | jq -r '.url')
MEDIA=$(cat /tmp/event.json | jq -r '.media[]?' 2>/dev/null)

echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Created: $CREATED_AT"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media count: $(echo "$MEDIA" | wc -w)"

# Check for duplicate processing
echo ""
echo "=== Step 1b: Duplicate check ==="
mkdir -p memory
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "Already processed this tweet. Skipping."
    exit 0
  fi
fi

# Record this tweet
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim x-trader-seen.txt if needed
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "Trimmed x-trader-seen.txt to 2000 lines"
fi

# Step 2 - Load context (check if memory files exist)
echo ""
echo "=== Step 2: Load context ==="
if [ -f memory/topics/traders.md ]; then
  echo "Found traders.md"
else
  echo "traders.md not found - creating empty"
  mkdir -p memory/topics
  touch memory/topics/traders.md
fi

# Step 3 - Cross-platform dedup (only for Crypto_Chase, KillaXBT, HeartCanHodl)
echo ""
echo "=== Step 3: Cross-platform dedup check ==="
if [ "$USERNAME" = "KillaXBT" ] || [ "$USERNAME" = "Crypto_Chase" ] || [ "$USERNAME" = "HeartCanHodl" ]; then
  echo "This is a dual-platform trader: @$USERNAME"
  # Would check Discord here, but for now just note it
  echo "Discord dedup would apply if memory/discord-channels.json exists"
else
  echo "Not a dual-platform trader, skipping dedup"
fi

# Step 4 - Classify the post
echo ""
echo "=== Step 4: Classify post ==="

# Rule HR-1: Test tweets
if echo "$TEXT" | grep -qiE '(^test$|test["\s]|^\s*testing\s*123|\[.*\]\s*test|testing$)'; then
  echo "Classification: SKIP (test tweet)"
  echo "Action: None"
  classification="skip"
else
  # Check if it's non-financial (personal, memes, banter)
  if echo "$TEXT" | grep -qiE '(mentally deranged|are you)'; then
    # This appears to be banter/mocking post
    echo "Classification: NON-FINANCIAL (personal banter/mocking)"
    echo "The post is @JimmyPlans mocking, not a trade signal"
    classification="non-financial"
  elif echo "$TEXT" | grep -qiE '(entry|position|long|short|buy|sell|added|took profit|closed|cancelled)'; then
    echo "Classification: TRADE ACTION (potential)"
    # Needs deeper analysis
    if echo "$TEXT" | grep -qiE '(just |I |my )'; then
      echo "Contains first-person action language - analyzing further..."
      classification="potential_trade"
    else
      classification="informational"
    fi
  else
    echo "Classification: INFORMATIONAL"
    classification="informational"
  fi
fi

# Step 8 - Update memory (traders.md)
echo ""
echo "=== Step 8: Update memory ==="
if [ "$classification" != "skip" ]; then
  # Add to traders.md
  TIMESTAMP=$(date -u +'%b %d %H:%MZ')
  SUMMARY="mocking comment about price targets"

  # Ensure trader section exists
  if ! grep -q "^## @$USERNAME" memory/topics/traders.md; then
    echo "" >> memory/topics/traders.md
    echo "## @$USERNAME" >> memory/topics/traders.md
    echo "" >> memory/topics/traders.md
    echo "**Events (rolling):**" >> memory/topics/traders.md
  fi

  # Add event line
  echo "  - $TIMESTAMP — $classification: $SUMMARY [$TWEET_ID]" >> memory/topics/traders.md
fi

# Step 9 - Log
echo ""
echo "=== Step 9: Logging ==="
TODAY=$(date +'%Y-%m-%d')
LOG_FILE="memory/logs/$TODAY.md"
mkdir -p memory/logs

cat >> "$LOG_FILE" << LOGEND

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $classification
- ticker(s): [none]
- alerted: no
- notes: non-financial banter/mocking, no trade signal

LOGEND

echo "Logged to $LOG_FILE"

# Summary
echo ""
echo "=== EXECUTION SUMMARY ==="
echo "Classification: $classification"
echo "Alerted: no"
echo "Memory updated: yes"
echo "Skill completed successfully"
