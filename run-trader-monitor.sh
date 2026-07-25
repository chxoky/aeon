#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon
mkdir -p memory/logs memory/topics

# Extract values from the decoded event
EVENT_JSON=$(base64 -d < .tmp/event.b64)
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
TODAY=$(date '+%Y-%m-%d')

echo "✓ Event decoded successfully"
echo "  Tweet ID: $TWEET_ID"
echo "  Username: @$USERNAME"
echo "  Text: $TEXT"
echo ""

# Step: Check if already processed
if [ -f memory/x-trader-seen.txt ] && grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
  echo "⚠ Tweet already processed, skipping..."
  exit 0
fi

# Add to seen list for deduplication
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo "Classification analysis:"
echo "========================"

# HR-1: Check for test tweets
if echo "$TEXT" | grep -iE '(test|testing 123|testing)' > /dev/null 2>&1; then
  echo "Result: SKIP - Test tweet pattern detected"
  CLASSIFICATION="skip"
else
  # Check for financial keywords
  if echo "$TEXT" | grep -iE '(@|long|short|bull|bear|crypto|btc|eth|sell|buy|price|chart|position|entry|target|filled|cancelled|added|scaled)' > /dev/null 2>&1; then
    echo "Result: Potential financial content detected"
    # Check for first-person trade execution language
    if echo "$TEXT" | grep -iE '(just (longed|shorted|filled|bought|sold|entered|exited)|took profit|cancelled.*order|added.*position|scaling in|covered|closed)' > /dev/null 2>&1; then
      CLASSIFICATION="trade-action"
      echo "  → Trade action detected (first-person execution)"
    else
      CLASSIFICATION="informational"
      echo "  → Informational only (opinion/idea/level, not personal action)"
    fi
  else
    echo "Result: Non-financial content"
    CLASSIFICATION="skip"
  fi
fi

echo ""
echo "Final Classification: $CLASSIFICATION"
echo ""

# Step 8: Update memory
if [ "$CLASSIFICATION" != "skip" ]; then
  # Initialize trader section if needed
  if [ ! -f memory/topics/traders.md ]; then
    echo "# Traders Memory" > memory/topics/traders.md
  fi

  if ! grep -q "^## @$USERNAME" memory/topics/traders.md; then
    echo "" >> memory/topics/traders.md
    echo "## @$USERNAME" >> memory/topics/traders.md
    echo "**Events (rolling):**" >> memory/topics/traders.md
  fi

  # Add event line (max 200 chars per spec)
  TIMESTAMP=$(date '+%b %d %H:%M')
  EVENT_SUMMARY=$(echo "$TEXT" | cut -c1-30)
  echo "  - $TIMESTAMP Z — $CLASSIFICATION: $EVENT_SUMMARY... [$TWEET_ID]" >> memory/topics/traders.md
  echo "✓ Updated traders.md"
fi

# Step 9: Append to daily log
LOG_FILE="memory/logs/${TODAY}.md"
if [ ! -f "$LOG_FILE" ]; then
  echo "# Daily Log — $TODAY" > "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
echo "### x-trader-monitor (real-time event)" >> "$LOG_FILE"
echo "- trader: @$USERNAME" >> "$LOG_FILE"
echo "- tweet_id: $TWEET_ID" >> "$LOG_FILE"
echo "- classification: $CLASSIFICATION" >> "$LOG_FILE"
echo "- ticker(s): none" >> "$LOG_FILE"
echo "- alerted: $([ "$CLASSIFICATION" = "skip" ] && echo "no" || echo "yes")" >> "$LOG_FILE"
echo "- text: $TEXT" >> "$LOG_FILE"
echo "- url: $URL" >> "$LOG_FILE"

echo "✓ Updated daily log"
echo ""

# Determine if alert should be sent
if [ "$CLASSIFICATION" = "skip" ]; then
  echo "📋 Result: Silent skip (non-financial content)"
elif [ "$CLASSIFICATION" = "informational" ]; then
  echo "🔔 Alert Type: INFORMATIONAL"
  echo ""
  echo "Would send:"
  echo "🐦 *[X] @$USERNAME*"
  echo ""
  echo "$TEXT"
  echo ""
  echo "[View tweet]($URL)"
else
  echo "🚨 Alert Type: TRADE SIGNAL"
  echo ""
  echo "Would send:"
  echo "🚨 *Trade Signal — @$USERNAME*"
  echo ""
  echo "$TEXT"
  echo ""
  echo "[View post]($URL)"
fi
