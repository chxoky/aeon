#!/bin/bash

TWEET_ID="2081605684785811517"
USERNAME="swarmister"
TEXT="@garbycan 2in1"
URL="https://x.com/swarmister/status/2081605684785811517"
CREATED_AT="Mon Jul 27 05:00:44 +0000 2026"

echo "=== X-TRADER-MONITOR EXECUTION ==="
echo "Processing tweet from @$USERNAME"
echo "Tweet ID: $TWEET_ID"
echo "Text: $TEXT"
echo ""

# Check if already seen
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "⚠️  Already processed this tweet (duplicate), exiting silently."
  echo "## Log entry:"
  echo "- tweet_id: $TWEET_ID"
  echo "- classification: duplicate"
  echo "- alerted: no"
  exit 0
fi

# Add to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen list if needed
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo ""
echo "=== CLASSIFICATION ==="
echo ""
echo "Profile: swarmister — ~80% banter, 20% technical"
echo "Tweet type: terse cryptic one-word reply (@garbycan 2in1)"
echo "Has ticker: NO"
echo "Has price/level: NO"
echo "Has execution language: NO"
echo "Media: NONE"
echo ""
echo "Assessment:"
echo "- Conviction notes: 'one-word replies = near-zero' signal weighting"
echo "- Pattern: matches 30+ PENDING cryptic one-liners (non-alerted)"
echo "- Likely: social banter or external paid-call reference (unresolved)"
echo ""
echo "Decision: AMBIGUOUS / NON-FINANCIAL (silent, no alert)"
echo ""

# Append to traders.md
echo "Updating traders.md..."
# Find swarmister section and append to events
cat >> memory/topics/traders.md << 'EOF'
  - Jul 27 05:00Z — ambiguous: terse cryptic reply "@garbycan 2in1"; one-word pattern, no ticker/level [2081605684785811517]
EOF

echo "✅ Added to traders.md"
echo ""

# Create log entry for daily log
LOG_DATE=$(date -u +%Y-%m-%d)
echo "Creating log entry in memory/logs/$LOG_DATE.md..."

if [ ! -f "memory/logs/$LOG_DATE.md" ]; then
  mkdir -p memory/logs
  cat > "memory/logs/$LOG_DATE.md" << 'LOGEOF'
# Activity Log — 2026-07-27

LOGEOF
fi

cat >> "memory/logs/$LOG_DATE.md" << LOGEOF

### x-trader-monitor (real-time event)
- trader: @swarmister
- tweet_id: $TWEET_ID
- classification: ambiguous
- ticker(s): [none]
- alerted: no
- notes: terse one-word reply, no ticker/level, matches PENDING pattern, signal weight = near-zero per conviction notes

LOGEOF

echo "✅ Log entry created"
echo ""
echo "=== RESULT ==="
echo "Status: ✅ PROCESSED"
echo "Classification: ambiguous/non-financial"
echo "Alert sent: NO"
echo "Trader updated: YES (memory/topics/traders.md)"
echo "Log updated: YES (memory/logs/2026-07-27.md)"
