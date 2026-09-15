#!/bin/bash
set -euo pipefail

TWEET_ID="2099754897637847323"
USERNAME="t_in_crypto"
TEXT="Even lower soon \$btc"
URL="https://x.com/t_in_crypto/status/2099754897637847323"

echo "=== Processing Tweet ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo ""

# Check if already seen
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^${TWEET_ID}$" memory/x-trader-seen.txt; then
    echo "DUPLICATE: Tweet already processed"
    exit 0
  fi
fi

echo "First time seeing this tweet - proceeding"

# Step 4: Classify the post
# A. Check for non-financial content
# B. Check if cryptic/hard to interpret
# C. Check if trader is taking personal action

echo ""
echo "=== Classification Analysis ==="
echo "Text analysis:"
echo "- Mentions ticker: \$btc (yes)"
echo "- Contains action words (just, filled, added, cancelled, took profit): (no)"
echo "- Language: directional prediction/opinion, not personal action"
echo "- Media: empty"
echo ""

# HR-1: Check for test tweets
if echo "$TEXT" | grep -qi "^test\|test$\|\[.*\] test\|testing"; then
  echo "HARDCODED RULE HR-1: Test tweet - skipping silently"
  exit 0
fi

echo "Classification: INFORMATIONAL"
echo "- Not a test tweet (HR-1 pass)"
echo "- Not personal action (trader is predicting, not executing)"
echo "- Financially relevant (mentions BTC direction)"
echo "- Should alert as informational view"
