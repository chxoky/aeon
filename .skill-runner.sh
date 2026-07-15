#!/bin/bash
set -e

# Decoded event from provided var
cat > /tmp/decoded_event.json <<'EVENT_EOF'
{
  "id": "2077246275896934841",
  "username": "Wild_Randomness",
  "text": "@mrricci0x Hahaa too good– I just had ramen after tennis🏓\n\nDoes that count?",
  "created_at": "Wed Jul 15 04:18:00 +0000 2026",
  "url": "https://x.com/Wild_Randomness/status/2077246275896934841",
  "media": []
}
EVENT_EOF

EVENT_JSON=$(cat /tmp/decoded_event.json)
echo "=== EVENT DECODED ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')

echo ""
echo "=== FIELD EXTRACTION ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"

# Step 1: Check if already seen
echo ""
echo "=== STEP 1: DEDUP CHECK ==="
SEEN_FILE="memory/x-trader-seen.txt"
if grep -q "^$TWEET_ID$" "$SEEN_FILE" 2>/dev/null; then
  echo "DUPLICATE: Tweet ID already in x-trader-seen.txt. Stopping."
  echo "2026-07-15 processed (duplicate skip): $USERNAME tweet_id=$TWEET_ID" >> "memory/logs/2026-07-15.md"
  exit 0
else
  echo "NEW: Tweet ID not in x-trader-seen.txt. Proceeding."
fi

# Step 2: Load context (already done via Read)
echo ""
echo "=== STEP 2: CONTEXT LOADED ==="
echo "Trader context: Wild_Randomness — equities/vol trader, mostly flat"
echo "Last activity: 2026-07-15 03:46:45 UTC (Korea/Hynix TP target update)"

# Step 3: Cross-platform dedup (skip — not one of three dual-platform traders)
echo ""
echo "=== STEP 3: CROSS-PLATFORM DEDUP ==="
echo "SKIP: $USERNAME is not a dual-platform trader (not Crypto_Chase/KillaXBT/HeartCanHodl)"

# Step 4: CLASSIFICATION
echo ""
echo "=== STEP 4: CLASSIFICATION ==="
echo "Text analysis:"
echo "  - '@mrricci0x Hahaa too good– I just had ramen after tennis🏓'"
echo "  - 'Does that count?'"
echo ""
echo "Classification: A. NON-FINANCIAL"
echo "Reasoning: Personal life post (food + exercise) with no financial signal."
echo "Action: SKIP — do not store, do not alert."

# Step 5: NO ACTION REQUIRED (classification is SKIP)
echo ""
echo "=== STEP 5: SKIP ACTION ==="
echo "No alert, no memory update for position/trades, silent log only."

# Step 6: UPDATE MEMORY
echo ""
echo "=== STEP 6: UPDATE MEMORY ==="

# 6a: Append to x-trader-seen.txt
echo "$TWEET_ID" >> "$SEEN_FILE"
echo "✓ Appended $TWEET_ID to $SEEN_FILE"

# 6b: Append to traders.md
cat >> "memory/topics/traders.md" <<TRADER_LOG

- Jul 15 04:18:00 — skip (non-financial / personal life) — "@mrricci0x Hahaa too good– I just had ramen after tennis🏓\n\nDoes that count?" — Personal banter about food/exercise, no market signal. Silent log.
TRADER_LOG
echo "✓ Appended event log to traders.md"

# Step 7: LOG TO DAILY LOG
echo ""
echo "=== STEP 7: DAILY LOG ==="
mkdir -p memory/logs

cat >> "memory/logs/2026-07-15.md" <<DAILY_LOG

### x-trader-monitor (real-time event)
- trader: @Wild_Randomness
- tweet_id: 2077246275896934841
- classification: skip
- ticker(s): N/A
- alerted: no
- notes: Personal life (ramen after tennis), non-financial, silent log

DAILY_LOG
echo "✓ Appended daily log entry"

echo ""
echo "=== COMPLETE ==="
echo "Event processed. No alert sent. Memory updated."
