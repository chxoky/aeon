#!/bin/bash
# x-trader-monitor event processor for real-time tweet from KillaXBT

TWEET_ID="2077014492064436384"
USERNAME="KillaXBT"
URL="https://x.com/KillaXBT/status/2077014492064436384"
CREATED_AT="Tue Jul 14 12:56:58 +0000 2026"
TODAY="2026-07-14"

# Decoded tweet text:
TEXT="This phase of the \$BTC cycle is literally engineered to steal your money.

They'll chop this range relentlessly until everyone is heavily overleveraged in one direction.

Then, silently at first, then all at once. Same script every single cycle. What I've learned after years of this game... sometimes the most profitable move is simply holding your one high conviction trade that aligns with the bigger picture.

Instead of trying to scalp every little range, my advice is to sit back, relax for the next 2 months, wait for structure to clearly shift bullish, and then long your longs."

# CLASSIFICATION:
# - Not a test tweet (no "test", "testing" patterns)
# - Not non-financial (clearly about BTC market structure)
# - Not cryptic (clear strategic/philosophical commentary)
# - NOT a personal action (no "I just longed", "I'm entering", "I added here" language)
#   Rather: "wait for structure to clearly shift bullish, and then long your longs" = philosophical advice
# - VERDICT: Informational (broader market/macro view, HTF bullish conviction reaffirmation)

CLASSIFICATION="informational"
TICKER="BTC"
ALERT="yes"

echo "=== x-trader-monitor Event Processing ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Created: $CREATED_AT"
echo "Classification: $CLASSIFICATION ($TICKER)"
echo "Will alert: $ALERT"
echo ""

# Append tweet ID to seen list (before alerting, to prevent reprocessing on retry)
mkdir -p "$(dirname /home/runner/work/aeon/aeon/memory/x-trader-seen.txt)"
echo "$TWEET_ID" >> /home/runner/work/aeon/aeon/memory/x-trader-seen.txt

# Trim seen file if > 5000 lines
LINES=$(wc -l < /home/runner/work/aeon/aeon/memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 /home/runner/work/aeon/aeon/memory/x-trader-seen.txt > /home/runner/work/aeon/aeon/memory/x-trader-seen.tmp && mv /home/runner/work/aeon/aeon/memory/x-trader-seen.tmp /home/runner/work/aeon/aeon/memory/x-trader-seen.txt
fi

echo "✓ Recorded tweet ID in x-trader-seen.txt (${LINES} total lines)"
echo ""

# Prepare alert message
cat > /tmp/trader-alert.txt <<'EOF'
🐦 *[X] @KillaXBT*

This phase of the $BTC cycle is literally engineered to steal your money.

They'll chop this range relentlessly until everyone is heavily overleveraged in one direction.

Then, silently at first, then all at once. Same script every single cycle. What I've learned after years of this game... sometimes the most profitable move is simply holding your one high conviction trade that aligns with the bigger picture.

Instead of trying to scalp every little range, my advice is to sit back, relax for the next 2 months, wait for structure to clearly shift bullish, and then long your longs.

[View tweet](https://x.com/KillaXBT/status/2077014492064436384)

↳ _Aligns with his existing 2x BTC long from 62.6K conviction; reinforces HTF bullish lean against near-term chop thesis._
EOF

echo "Alert prepared at /tmp/trader-alert.txt"

# Show the alert
echo "---"
cat /tmp/trader-alert.txt
echo "---"
