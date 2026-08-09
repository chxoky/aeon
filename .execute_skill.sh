#!/bin/bash

# X Trader Monitor Skill Execution
# Event: Wild_Randomness tweet

TWEET_ID="2086545231520919750"
USERNAME="Wild_Randomness"
URL="https://x.com/Wild_Randomness/status/2086545231520919750"
TODAY=$(date +"%Y-%m-%d")

# Setup
mkdir -p memory
SEEN_FILE="memory/x-trader-seen.txt"

# Check if already processed
if [ -f "$SEEN_FILE" ] && grep -q "^$TWEET_ID$" "$SEEN_FILE"; then
  echo "X_TRADER_DUPLICATE: $TWEET_ID already processed"
  exit 0
fi

# Add to seen list
echo "$TWEET_ID" >> "$SEEN_FILE"

# Trim if too large (keep last 2000)
LINES=$(wc -l < "$SEEN_FILE" 2>/dev/null)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 "$SEEN_FILE" > "$SEEN_FILE.tmp"
  mv "$SEEN_FILE.tmp" "$SEEN_FILE"
fi

# CLASSIFICATION: This is a home improvement post (kitchen ceiling range hood)
# Not financial/trading related → Non-financial (Step 4A)
CLASSIFICATION="skip"

# Update traders.md with event entry
TRADERS_FILE="memory/topics/traders.md"
mkdir -p memory/topics

# Create/append to traders.md if needed
if [ ! -f "$TRADERS_FILE" ]; then
  cat > "$TRADERS_FILE" << 'EOF'
# Traders Memory

## Wild_Randomness
**Conviction:** TBD
**Current open positions:** None tracked
**Recent thesis:** Non-financial banter
**Last seen:** 2026-08-09 20:08
**Calibration:** Kitchen/home improvement posts (non-trader)

**Events (rolling):**
EOF
fi

# Log to daily log
mkdir -p memory/logs
LOG_FILE="memory/logs/${TODAY}.md"

if [ ! -f "$LOG_FILE" ]; then
  echo "# Skill Runs — $TODAY" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @${USERNAME}
- tweet_id: ${TWEET_ID}
- classification: ${CLASSIFICATION}
- ticker(s): none
- alerted: no
- notes: Home improvement post (ceiling range hood), not financial. Non-financial skip per HR-1 pattern.

EOF

echo "✓ Classification: $CLASSIFICATION"
echo "✓ Logged to memory/logs/${TODAY}.md"
echo "✓ No alert sent (non-financial)"
