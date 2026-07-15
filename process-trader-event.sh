#!/bin/bash
set -e

# Trader event from environment
TWEET_ID="2077390716406264244"
USERNAME="HeartCanHodl"
TEXT="20 minutes into market open 🎻 https://t.co/oDOffyypNU"
URL="https://x.com/HeartCanHodl/status/2077390716406264244"
TODAY="2026-07-15"

echo "=== x-trader-monitor: Processing event ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"

# Step 1: Check if already seen
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^${TWEET_ID}$" memory/x-trader-seen.txt; then
    echo "✓ Tweet already processed — skipping"
    exit 0
  fi
fi

# Step 2: Load memory context
echo ""
echo "=== Loading memory context ==="

if [ -f "memory/topics/traders.md" ]; then
  echo "Found traders.md"
  grep -A 10 "^## $USERNAME" memory/topics/traders.md 2>/dev/null || echo "No context for $USERNAME yet"
else
  echo "No traders.md found yet"
fi

# Step 3: Classify the post
echo ""
echo "=== Classification ==="
echo "Post: '$TEXT'"
echo ""
echo "Analysis:"
echo "- Non-financial? NO - references market open and contains a link"
echo "- Cryptic/hard to interpret? YES - just a reference to market open with emoji and link, no context"
echo "- Is this the trader taking action? NO - just commenting on time of day"
echo ""
echo "→ This is an AMBIGUOUS/CRYPTIC post"
echo "   The emoji (🎻) and link suggest some significance, but without seeing the linked content,"
echo "   it's unclear whether this is:"
echo "   a) A casual market-timing observation"
echo "   b) A market sentiment signal"
echo "   c) Something else entirely"

# Step 4: Determine next action
echo ""
echo "=== Action ==="
echo "Classification: AMBIGUOUS"
echo "Next step: Send calibration alert to Kyle asking for interpretation"

# Step 5: Create calibration alert
CALIBRATION_MSG=$(cat <<'EOF'
🔍 *Calibration — @HeartCanHodl*

Event: Trader posted at market open

HeartCanHodl: "20 minutes into market open 🎻 https://t.co/oDOffyypNU"

Unable to classify — what's your read? The emoji and link suggest this might signal something, but without context it's ambiguous.
EOF
)

echo ""
echo "Calibration alert:"
echo "$CALIBRATION_MSG"

# Step 6: Update memory
echo ""
echo "=== Updating memory ==="
mkdir -p memory/topics memory/logs

# Add to traders.md if not exists
if [ ! -f "memory/topics/traders.md" ]; then
  cat > memory/topics/traders.md << 'TEOF'
# Trader Context & Thesis Tracking

## HeartCanHodl

Active tracking — posts on both X and Discord.

Recent activity:
- 2026-07-15 13:51:57: AMBIGUOUS — "20 minutes into market open 🎻" (link to external content) — awaiting Kyle's read
TEOF
else
  # Check if HeartCanHodl section exists, if not add it
  if ! grep -q "^## HeartCanHodl" memory/topics/traders.md; then
    echo "" >> memory/topics/traders.md
    echo "## HeartCanHodl" >> memory/topics/traders.md
    echo "" >> memory/topics/traders.md
    echo "Active tracking — posts on both X and Discord." >> memory/topics/traders.md
  fi

  echo "- 2026-07-15 13:51:57: AMBIGUOUS — \"20 minutes into market open 🎻\" (link to external content) — awaiting Kyle's read" >> memory/topics/traders.md
fi

# Add tweet ID to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim if too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Step 7: Log the event
echo ""
echo "=== Logging event ==="

LOG_DIR="memory/logs"
LOG_FILE="${LOG_DIR}/${TODAY}.md"
mkdir -p "$LOG_DIR"

if [ ! -f "$LOG_FILE" ]; then
  echo "# Activity Log — 2026-07-15" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << 'LOGEOF'

### x-trader-monitor (real-time event)
- trader: @HeartCanHodl
- tweet_id: 2077390716406264244
- classification: ambiguous
- ticker(s): [none]
- alerted: yes (calibration)
- notes: Cryptic post at market open with external link — unable to classify without Kyle's context
LOGEOF

echo "✓ Logged to $LOG_FILE"

# Step 8: Send notification (simulate)
echo ""
echo "=== Summary ==="
echo "✓ Event processed"
echo "✓ Classification: AMBIGUOUS"
echo "✓ Alert ready: calibration"
echo "✓ Memory updated"
echo "✓ Logged"
echo ""
echo "Next: Send calibration alert via ./notify"

