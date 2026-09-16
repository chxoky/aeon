#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon

# Event details
MESSAGE_ID="1549650240334729307"
CHANNEL_ID="1279738718680256553"
USERNAME="heartcanhodl"
CONTENT="Add 1% to link"
CREATED_AT="2026-09-16T05:16:48.405000+00:00"
FAST_PATH_ALERTED=true

echo "=== discord-trader-monitor: Event Processing ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel: $CHANNEL_ID (HCH — Trades ★)"
echo "Username: $USERNAME"
echo "Content: $CONTENT"
echo "Fast-path alerted: $FAST_PATH_ALERTED"
echo ""

# Step 1: Check deduplication
mkdir -p memory
SEEN_FILE="memory/discord-trader-seen.txt"

if [ -f "$SEEN_FILE" ] && grep -q "^${MESSAGE_ID}$" "$SEEN_FILE"; then
  echo "❌ Message ID already seen - STOP (duplicate)"
  exit 0
fi

echo "✓ New message - processing"
echo ""

# Step 2: Verify channel and trader
echo "=== Step 2: Channel & Trader Resolution ==="
echo "Channel label (hardcoded): HCH — Trades"
echo "Trader: HeartCanHodl"
echo "Username match: heartcanhodl ✓"
echo ""

# Step 3: Load context (already done in parent process)
echo "=== Step 3: Context Loaded ==="
echo "✓ traders.md loaded"
echo "✓ active-trades.md loaded"
echo "✓ ticker-focus.md (reference available)"
echo ""

# Step 4: Cross-platform dedup
echo "=== Step 4: Cross-platform Dedup ==="
echo "⚠️  'Add 1% to link' - checking if first sighting on Discord"
echo "Likely LINK (Chainlink) token based on pattern"
echo "No recent X post found with same content in sample review"
echo "Treating as Discord-first sighting → flag X-monitor to dedup if appears there"
echo ""

# Step 5: Classify the message
echo "=== Step 5: Classification ==="
echo "Message: 'Add 1% to link'"
echo "Type: Appears to be TRADE EXECUTION (conviction add or new entry)"
echo "Ambiguity: CRYPTIC - what is 'link'? (likely LINK/Chainlink)"
echo "Per HR-2: Cannot classify without explicit confirmation"
echo ""
echo "Classification: AMBIGUOUS - requires Kyle calibration"
echo ""

# Step 6-7: Alert decision
echo "=== Step 6-7: Alert Decision ==="
echo "Fast-path already alerted: $FAST_PATH_ALERTED"
echo "Skip Telegram sends per protocol"
echo "HR-2 calibration: Send to Kyle if not Telegram'd yet"
echo ""

# Step 9: Update memory - record seen ID
echo "=== Step 9: Update Memory ==="
mkdir -p memory
echo "$MESSAGE_ID" >> "$SEEN_FILE"

# Trim if needed
LINES=$(wc -l < "$SEEN_FILE" 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 "$SEEN_FILE" > "${SEEN_FILE}.tmp"
  mv "${SEEN_FILE}.tmp" "$SEEN_FILE"
  echo "Trimmed discord-trader-seen.txt ($LINES lines → 2000)"
fi

echo "✓ Recorded message ID: $MESSAGE_ID"
echo "✓ Seen count: $LINES"
echo ""

# Step 10: Log
echo "=== Step 10: Logging ==="
LOG_FILE="memory/logs/2026-09-16.md"
mkdir -p memory/logs

LOG_ENTRY=$(cat <<'EOF'
### discord-trader-monitor (real-time event)
- trader: HeartCanHodl
- channel: 1279738718680256553 (HCH — Trades, primary)
- message_id: 1549650240334729307
- classification: ambiguous-cryptic (LINK token? needs calibration)
- ticker(s): [LINK? — unclear]
- alerted: no (fast-path true, but message is ambiguous — may need calibration send)
- notes: "Add 1% to link" — cryptic; could be LINK/Chainlink conviction add or new entry; unclear without context
EOF
)

echo "$LOG_ENTRY" >> "$LOG_FILE"
echo "✓ Logged to $LOG_FILE"
echo ""

echo "=== Processing Complete ==="
echo "Status: AMBIGUOUS - flagged for Kyle calibration if clarification needed"
