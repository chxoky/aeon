#!/bin/bash

TWEET_ID="2079090669046349976"
USERNAME="swarmister"
TEXT="@zackvoell Say no to woman"
CREATED_AT="Mon Jul 20 06:26:57 +0000 2026"
URL="https://x.com/swarmister/status/2079090669046349976"
TODAY="2026-07-20"

# Check if tweet has been seen before
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^${TWEET_ID}$" memory/x-trader-seen.txt; then
    echo "DUPLICATE_TWEET: Already processed tweet ID $TWEET_ID"
    exit 0
  fi
fi

echo "=== X-Trader Monitor Execution ==="
echo "Event: @$USERNAME on $CREATED_AT"
echo "Text: $TEXT"
echo ""

# Classification Analysis per Step 4
echo "Classification Analysis:"
echo "✗ Not a test tweet (no 'test' keyword)"
echo "✗ Not cryptic financial content"
echo "✗ Not a personal trade action"
echo "✗ Not an opinion on market direction"
echo "→ Classification: NON-FINANCIAL (personal banter)"
echo ""

echo "Action: Skip silently (no alert, no memory update for trade)"
echo ""

# Add to seen list to prevent reprocessing
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim the seen list if it gets too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Log the event
mkdir -p memory/logs
cat >> "memory/logs/${TODAY}.md" <<LOG_ENTRY

### x-trader-monitor (real-time event)
- trader: @${USERNAME}
- tweet_id: ${TWEET_ID}
- classification: skip
- ticker(s): none
- alerted: no
- notes: Personal banter, non-financial content — skipped per HR classification

LOG_ENTRY

echo "Logged to memory/logs/${TODAY}.md"
echo "Status: ✓ Processed successfully (skip)"
