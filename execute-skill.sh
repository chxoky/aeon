#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon

# Step 1: Decode the event
EVENT_JSON=$(echo "${var}" | base64 -d 2>/dev/null)

# Check if decoding succeeded
if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: ${var}"
  exit 1
fi

# Parse the event
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

echo "=== Decoded Event ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media: ${MEDIA:-none}"
echo ""

# Step 2: Check if already seen
mkdir -p memory
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "Already processed, skipping..."
  exit 0
fi

# Add to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Step 3: Classification logic
echo "=== Classification ==="

# HR-1: Test tweets
if echo "$TEXT" | grep -iE '(test|testing|testing 123)' > /dev/null; then
  echo "Classification: SKIP (test tweet pattern)"
  echo "Action: Silent skip"
else
  # Check for financial relevance
  if echo "$TEXT" | grep -iE '(@|long|short|bull|bear|crypto|btc|eth|sell|buy|price|chart|position|entry|target|short|filled|cancelled|added)' > /dev/null; then
    echo "Classification: INFORMATIONAL/TRADE SIGNAL"

    # HR-2: Check for trade action keywords (first-person execution)
    if echo "$TEXT" | grep -iE '(just (longed|shorted|filled|bought|sold)|took profit|cancelled.*order|added|scaling in)' > /dev/null; then
      echo "Trade Action Detected: YES"
      echo "Alert Type: TRADE SIGNAL"

      # Generate trade alert
      ALERT="🚨 *Trade Signal — @${USERNAME}*

$TEXT

[View post](${URL})"
    else
      echo "Trade Action Detected: NO"
      echo "Alert Type: INFORMATIONAL"

      # Generate informational alert
      ALERT="🐦 *[X] @${USERNAME}*

$TEXT

[View post](${URL})"
    fi
  else
    echo "Classification: SKIP (non-financial)"
    echo "Action: Silent skip"
    ALERT=""
  fi
fi

# Step 4: Update memory files
echo ""
echo "=== Memory Updates ==="

# Ensure memory directories exist
mkdir -p memory/logs memory/topics

# Append to traders.md
if [ ! -f memory/topics/traders.md ]; then
  echo "## Traders Memory" > memory/topics/traders.md
fi

# Add entry to trader section (or create if missing)
if ! grep -q "^## $USERNAME" memory/topics/traders.md; then
  echo "" >> memory/topics/traders.md
  echo "## @$USERNAME" >> memory/topics/traders.md
  echo "" >> memory/topics/traders.md
  echo "**Events (rolling):**" >> memory/topics/traders.md
fi

# Append event (max 200 chars)
EVENT_LINE=$(printf "  - $(date '+%b %d %H:%M')Z — informational: $(echo "$TEXT" | cut -c1-30)... [$TWEET_ID]")
sed -i "/^## $USERNAME/,/^## / { /^## [^$]/!a $EVENT_LINE
}" memory/topics/traders.md

# Create/append to daily log
TODAY=$(date '+%Y-%m-%d')
LOG_FILE="memory/logs/${TODAY}.md"
if [ ! -f "$LOG_FILE" ]; then
  echo "# Daily Log — $TODAY" > "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
echo "### x-trader-monitor (real-time event)" >> "$LOG_FILE"
echo "- trader: @$USERNAME" >> "$LOG_FILE"
echo "- tweet_id: $TWEET_ID" >> "$LOG_FILE"
echo "- text: $TEXT" >> "$LOG_FILE"
echo "- url: $URL" >> "$LOG_FILE"
echo "- classification: informational" >> "$LOG_FILE"

# Step 5: Send notification if applicable
echo ""
echo "=== Notification ==="
if [ -n "$ALERT" ]; then
  echo "Sending alert:"
  echo "$ALERT"
  echo ""
  # In real execution, this would call: ./notify "$ALERT"
else
  echo "No alert sent (non-financial or test tweet)"
fi

echo ""
echo "=== Skill Complete ==="
