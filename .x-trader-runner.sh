#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon

# Decode event from var
EVENT_JSON=$(echo "eyJpZCI6IjIwNzk3MjgzNDE2NjY0MTA2NzkiLCJ1c2VybmFtZSI6InRfaW5fY3J5cHRvIiwidGV4dCI6IkBLYXR6YXJza2FSIEB0aWdlcl9raGFuOSB0aGF0IGhlIGlzIHBlcnNpc3RlbnRseSBzZWVraW5nIGFueSBjb25maXJtYXRpb24gb2YgaGlzIHJpZ2h0bmVzcyAtIHRoYXQgdGhlIGJvdHRvbSBoYXMgYmVlbiByZWFjaGVkIGFuZCB3ZSBhcmUgc3RhcnRpbmcgYSBuZXcgYnVsbCBtYXJrZXQgcmlnaHQgbm93IiwiY3JlYXRlZF9hdCI6IldlZCBKdWwgMjIgMDA6NDA6NTAgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vdF9pbl9jcnlwdG8vc3RhdHVzLzIwNzk3MjgzNDE2NjY0MTA2NzkiLCJtZWRpYSI6W119" | base64 -d)

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
MEDIA=$(echo "$EVENT_JSON" | jq '.media')

echo "=== EVENT DECODED ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"

# Step: Check for duplicates
mkdir -p memory
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^$TWEET_ID\$" memory/x-trader-seen.txt; then
    echo "X_TRADER_DUPLICATE: Already processed"
    exit 0
  fi
fi

# Step: Check hardcoded rules (HR-1: Test tweets)
if echo "$TEXT" | grep -iE '\btest\b|testing' > /dev/null; then
  echo "HR-1: Classified as test tweet - skipping silently"
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Step: Load trader context
echo ""
echo "=== TRADER CONTEXT ==="
if [ -f memory/topics/traders.md ]; then
  # Extract t_in_crypto section
  sed -n '/^### @t_in_crypto/,/^### @/p' memory/topics/traders.md | head -20
fi

# Step: Classify the post
echo ""
echo "=== CLASSIFICATION LOGIC ==="
echo "1. Is this non-financial? NO - discusses market bottom and bull market"
echo "2. Is this cryptic/hard to interpret? MAYBE - indirect phrasing, commentary on someone else"
echo "3. Is trader describing PERSONAL action? NO - phrased as commentary on @KatzarskaR/@tiger_khan9"
echo ""
echo "VERDICT: AMBIGUOUS/INFORMATIONAL - cryptic, indirect phrasing about market sentiment"
echo "         Aligns with t_in_crypto's known bullish long position but phrased indirectly"
echo ""

# This is sentiment/informational - trader commenting on market direction, not personal trade action
CLASSIFICATION="ambiguous-informational"
ALERT_NEEDED="yes"
TICKERS="BTC"

echo "Sending calibration alert..."
