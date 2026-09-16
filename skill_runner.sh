#!/bin/bash
set -e

TWEET_ID="2100295273075347716"
USERNAME="abetrade"
TEXT="after many years of observing crypto twitter, which consists of professional fundamental analysts who occasionally share completely realistic sports bets, here is how you should view all Fed decisions:

rate hikes = bullish
rate cuts = bullish

hope this helps"
CREATED_AT="Wed Sep 16 18:46:29 +0000 2026"
URL="https://x.com/abetrade/status/2100295273075347716"
MEDIA="[]"
TODAY="2026-09-16"

echo "=== X-Trader Monitor Event Processing ==="
echo "Trader: @${USERNAME}"
echo "Tweet ID: ${TWEET_ID}"
echo "Time: ${CREATED_AT}"
echo ""

# Step 1: Check if tweet already processed
if grep -q "${TWEET_ID}" memory/x-trader-seen.txt 2>/dev/null; then
  echo "⚠️  DUPLICATE: Tweet ${TWEET_ID} already processed"
  exit 0
fi

# Step 4: Classification
echo "=== Classification ==="
echo "Post text:"
echo "${TEXT}"
echo ""
echo "Analysis:"
echo "- Non-financial? NO (Fed policy commentary)"
echo "- Cryptic/needs interpretation? YES"
echo "  - Sarcastic commentary on Fed decisions"
echo "  - Both hikes and cuts framed as bullish"
echo "  - Trader context: @abetrade = volatility specialist, no personal trades"
echo "- Personal action? NO (educational/sarcastic commentary)"
echo ""

CLASSIFICATION="informational-macro-sarcasm"
ALERT="no"

echo "Classification: ${CLASSIFICATION}"
echo "Alert Kyle? ${ALERT}"
echo ""

# Step 8: Update memory files
echo "=== Updating memory ==="

# Add to traders.md event log
mkdir -p memory/topics
EVENT_LINE="  - Sep 16 18:46Z — informational-macro-sarcasm: Fed policy sarcasm (both hikes/cuts bullish); educational commentary, no personal execution [$MACRO/$FED] [${TWEET_ID}]"

# Check if trader section exists and append
if grep -q "^## ${USERNAME}" memory/topics/traders.md 2>/dev/null; then
  echo "Appending to existing @${USERNAME} section..."
  # Find the Events line and add after it
  sed -i "/^## ${USERNAME}/,/^\*\*Events/s/^\(\*\*Events.*:\)$/\1\n${EVENT_LINE}/" memory/topics/traders.md 2>/dev/null || \
    echo "// Skipping memory update due to sed limitations"
else
  echo "No existing section for @${USERNAME} - new trader!"
  echo "" >> memory/topics/traders.md
  echo "## ${USERNAME}" >> memory/topics/traders.md
  echo "" >> memory/topics/traders.md
  echo "- Platforms: X (Twitter)" >> memory/topics/traders.md
  echo "- Current open positions: None (options volatility analyst)" >> memory/topics/traders.md
  echo "- Recent thesis: Educational posts on options volatility strategies" >> memory/topics/traders.md
  echo "- Conviction notes: No personal executions documented" >> memory/topics/traders.md
  echo "- Last seen: 2026-09-16T18:46:29Z" >> memory/topics/traders.md
  echo "- **Events (rolling):**" >> memory/topics/traders.md
  echo "${EVENT_LINE}" >> memory/topics/traders.md
fi

# Add to x-trader-seen.txt
mkdir -p memory
echo "${TWEET_ID}" >> memory/x-trader-seen.txt

# Keep file to 2000 lines max
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 2000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Step 9: Log to daily log
mkdir -p memory/logs
cat >> "memory/logs/${TODAY}.md" << 'LOGENTRY'

### x-trader-monitor (real-time event)
- trader: @abetrade
- tweet_id: 2100295273075347716
- classification: informational-macro-sarcasm
- ticker(s): [MACRO, $FED]
- alerted: no
- notes: Fed policy sarcasm/educational commentary, no personal trade signal

LOGENTRY

echo "✅ Memory updated"
echo "✅ Event logged to memory/logs/${TODAY}.md"
echo ""
echo "=== Summary ==="
echo "Status: PROCESSED (no alert)"
echo "Classification: Informational (sarcasm)"
echo "Action: Logged to memory (no notification to Kyle)"
