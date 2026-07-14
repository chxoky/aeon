#!/bin/bash
set -euo pipefail

VAR="eyJpZCI6IjIwNzcxNTkzNjU2ODYwMzg2NjUiLCJ1c2VybmFtZSI6IlN0b2lpaWMiLCJ0ZXh0IjoiZW5vdWdoIHBlb3BsZSBnZXQgZXhjaXRlZCAtJmd0OyByYW5nZSBkZXZlbG9wbWVudCB3b3VsZCBiZSBpZGVhbC4iLCJjcmVhdGVkX2F0IjoiVHVlIEp1bCAxNCAyMjozMjozOSArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9TdG9paWljL3N0YXR1cy8yMDc3MTU5MzY1Njg2MDM4NjY1IiwibWVkaWEiOltdfQ=="

# Step 1: Decode the event
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null || true)

if [ -z "$EVENT_JSON" ]; then
  echo "❌ X_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

# Parse the event
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null || true)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null || true)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null || true)

if [ -z "$TEXT" ] || [ -z "$TWEET_ID" ] || [ -z "$USERNAME" ]; then
  echo "❌ X_TRADER_BAD_EVENT: missing required fields"
  exit 1
fi

echo "✓ Decoded event:"
echo "  Tweet ID: $TWEET_ID"
echo "  Username: @$USERNAME"
echo "  Text: $TEXT"

# Step 2: Check if already processed
mkdir -p memory
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "⏭️  Already processed this tweet (dedup), skipping"
  exit 0
fi

# Step 3: Check for test tweets (HR-1)
if echo "$TEXT" | grep -iE '(^|[[:space:]])test([[:space:]]|$)|testing|test$' >/dev/null; then
  echo "🔇 Test tweet detected - skipping silently"
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Step 4: Load memory context
echo ""
echo "📚 Loading memory context..."
if [ -f memory/topics/traders.md ]; then
  echo "  ✓ traders.md found"
  grep "@$USERNAME" memory/topics/traders.md | head -3 || echo "  (no prior context for @$USERNAME)"
else
  echo "  (traders.md not found - first mention of this trader)"
fi

# Step 5: Classify
echo ""
echo "🔍 Classifying tweet..."

# Check if this looks like a personal action (first-person, execution-oriented)
if echo "$TEXT" | grep -iE '(just (longed|shorted|sold|bought|filled|added|closed)|took profit|cancelled|adding more|placed|executed)' >/dev/null; then
  echo "  → Looks like a TRADE ACTION"
  CLASSIFICATION="trade-action"
else
  echo "  → Looks like an INFORMATIONAL message (opinion/idea/suggestion)"
  CLASSIFICATION="informational"
fi

# Extract tickers (simple pattern)
TICKERS=$(echo "$TEXT" | grep -oE '\$[A-Z0-9]+' | tr '\n' ',' | sed 's/,$//') || true

echo "  Classification: $CLASSIFICATION"
echo "  Tickers found: ${TICKERS:-none}"

# Step 6: Update memory
echo ""
echo "💾 Updating memory..."
mkdir -p memory/topics memory/logs

# Add to seen tweets
echo "$TWEET_ID" >> memory/x-trader-seen.txt
# Trim if too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Append to traders.md
if [ ! -f memory/topics/traders.md ]; then
  cat > memory/topics/traders.md << 'EOF'
# Watched Traders - Real-time Notes

This file tracks all processed tweets from the 12 watched X accounts, with context about their positions and sentiment.

EOF
fi

TODAY=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

cat >> memory/topics/traders.md << EOF

## @$USERNAME — $TIMESTAMP
- **ID:** $TWEET_ID
- **Classification:** $CLASSIFICATION
- **Tickers:** ${TICKERS:-none}
- **Text:** "$TEXT"
- **Alerted:** no (informational - filed to memory)
EOF

# Log the event
LOG_FILE="memory/logs/$TODAY.md"
if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" << EOF
# Activity Log - $TODAY

EOF
fi

cat >> "$LOG_FILE" << EOF
### x-trader-monitor (real-time event) — $TIMESTAMP
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker(s): ${TICKERS:-none}
- alerted: no
- notes: $TEXT

EOF

echo "  ✓ Updated traders.md"
echo "  ✓ Logged to $LOG_FILE"
echo "  ✓ Added to seen tweets (dedup cache)"

# Step 7: Send alert if needed
echo ""
if [ "$CLASSIFICATION" = "trade-action" ]; then
  echo "🚨 Would send trade alert (trade action detected)"
  echo "   → Requires approval flow"
elif [ "$CLASSIFICATION" = "informational" ]; then
  echo "🐦 Informational message filed to memory"
  echo "   → No alert sent (contextual monitoring only)"
fi

echo ""
echo "✅ Skill execution complete"
