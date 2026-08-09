#!/bin/bash

# Update x-trader-seen.txt with new tweet ID
TWEET_ID="2086548256457183613"
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim if over 5000 lines
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Update traders.md with new event entry
cat >> memory/topics/traders.md << 'ENTRY'
  - Aug 09 20:20Z — informational: BTC weak vs GOLD (ratio analysis); alts opportunity (ETH.D compressed 10.55%); macro thesis [$BTC $GOLD] [2086548256457183613]
ENTRY

echo "Memory updated"
