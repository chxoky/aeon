#!/bin/bash
set -e

# Decode and process the event
VAR='eyJpZCI6IjIwNzg5NTMwNTMzNDkzNjM5NzAiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJCZWVuIGRvaW5nIHN0dWZmIGFyb3VuZCB0aGUgaG91c2UgYWxsIG1hdGNoIFxuXG5IYXZlbuKAmXQgZXZlbiB0dXJuZWQgdGhlIFRWIG9uXG5cbllvdSBqdXN0IGtub3cgaG93IHRoaXMgaXMgZ29pbmcgdG8gZW5kLCBzbyB3aHkgd2F0Y2g/IGh0dHBzOi8vdC5jby9KWFN5UFJzMUZpIiwiY3JlYXRlZF9hdCI6IlN1biBKdWwgMTkgMjE6MjA6MDcgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDc4OTUzMDUzMzQ5MzYzOTcwIiwibWVkaWEiOltdfQ=='

# Step 1: Decode
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "X_TRADER_BAD_EVENT: decode failed"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')

if [ -z "$TWEET_ID" ] || [ -z "$USERNAME" ] || [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: missing required fields"
  exit 1
fi

echo "✅ Event decoded successfully"
echo "  Tweet ID: $TWEET_ID"
echo "  Username: @$USERNAME"
echo "  Text: ${TEXT:0:80}..."
echo "  URL: $URL"
echo ""

# Step 2: Check if already seen
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "⚠️  Tweet already processed (dedup hit). Skipping."
  exit 0
fi

# Step 3: Classify the post
echo "📋 Classifying post..."

# Classification: This is clearly non-financial (personal life content about doing stuff around the house)
CLASSIFICATION="skip"
REASON="non-financial/personal-life"

if [ "$CLASSIFICATION" = "skip" ]; then
  echo "  → Classification: $CLASSIFICATION ($REASON)"
  echo "  → No alert sent"
fi

# Step 4: Update memory
echo ""
echo "💾 Updating memory..."

# Append to x-trader-seen.txt
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim if needed
LINES=$(wc -l < memory/x-trader-seen.txt)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "  → Trimmed x-trader-seen.txt ($LINES → 2000 lines)"
else
  echo "  → Added tweet_id to x-trader-seen.txt ($LINES lines)"
fi

# Append to traders.md with classification
echo "  → Recording in traders.md..."
cat >> memory/topics/traders.md << EOF
- **2026-07-19 21:20:07 UTC (X):** $CLASSIFICATION ($REASON) — "Been doing stuff around the house all match\n\nHaven't even turned the TV on\n\nYou just know how this is going to end, so why watch?" — Personal life content, no financial signal. Silent log. (tweet_id=$TWEET_ID)
EOF

# Step 5: Log
echo ""
echo "📝 Appending to log..."

LOGFILE="memory/logs/2026-07-19.md"
mkdir -p memory/logs

cat >> "$LOGFILE" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker(s): [none]
- alerted: no
- notes: personal/non-financial, silent skip

EOF

echo "  → Logged to $LOGFILE"
echo ""
echo "✅ Skill execution complete"
echo ""
echo "## Summary"
echo "- Event: Tweet from @$USERNAME (ID: $TWEET_ID)"
echo "- Classification: $CLASSIFICATION ($REASON)"
echo "- Action: Silent skip, no alert"
echo "- Memory updated: traders.md, x-trader-seen.txt, daily log"
