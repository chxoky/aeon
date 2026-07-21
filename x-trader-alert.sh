#!/bin/bash
set -e

# Tweet details
TWEET_ID="2079379986356765000"
USERNAME="HeartCanHodl"
TICKER="$SPCX"
URL="https://x.com/HeartCanHodl/status/20793799863567765000"
CREATED_AT="Tue Jul 21 01:36:36 +0000 2026"

# Step 8: Update memory

# Add to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen list if too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Step 6: Send informational alert
echo "🐦 *[X] @${USERNAME}*

\$SPCX has fallen roughly 46% from its 225 blow-off top.

Sentiment through the move:
• 150 to 225: \"I need to buy before it's too late. Space technology is the future.\"
• 225 to 170: \"Just a healthy pullback.\"
• 170 to 176: \"We're back!\"
• After 176 rejection: Finally they decide to sell.
• Then slow bleed began...

Now, back below the IPO price (~130):
We're becoming interested again but this time on the buy side. So at 121 and below it starts looking like a contrarian support zone worth watching.

[View tweet](${URL})" | tee alert.txt

# Also output for notify command
echo "Alert ready to send to Kyle via ./notify"
