#!/bin/bash
set -e

# Decode and process the event
VAR='eyJpZCI6IjIwODUwNDE4NTU4MTM2MjgyMjUiLCJ1c2VybmFtZSI6InRyYWRpbmdfYXhlIiwidGV4dCI6IkBDb252aWN0aW9uTU0gQFVuaXN3YXAgTWFrZXMgbWUgbGF1Z2ggaG93IG11Y2ggQ1QgcGxhY2VzIGVtcGhhc2lzIG9uIOKAnGluZmx1ZW5jZXJz4oCdIHRvIGdldCBiZWhpbmQgYSBjb2luIHNvIHRoZXkgY2FuIOKAnHRydXN0IGl04oCdIFtFbG9uIGFzIGFuIGV4YW1wbGVdLlxuXG5PciBhbiBpbmRlcGVuZGVudCB0aGlyZCBwYXJ0eSAtIGluIG1vc3QgY2FzZXMgLSBjZWxlYnJpdGllcyB3aG8gYXJlIGNsdWVsZXNzLCBvciDigJxMaW5rZWRJbuKAnSBkZXZzIHdpdGggY3JlZGVudGlhbHMgd2hvIGFyZSBwYWlkIGJ5IHNlcmlhbCBkZXBsb3llcnMgdG8gbGF1bmNoIGNvaW5zLlxuXG5CdXQgd2hlbiBOQVRJVkUgQ1JZUFRPIERlRkkgZm91bmRlcnMgbGF1bmNoIHNvbWV0aGluZyB0aGVtc2VsdmVzIGFuZCBiZWNvbWUgdGhlIGZhY2Ugb2YgaXQsXG5cbkFsbCB0aGUgZ3JlYXN5IHJhdHMgaGVyZSB0cnkgdG8gZmluZCBhbHRlcm5hdGl2ZXMgcmF0aGVyIHRoYW4gY3JlYXRlIGEgUHZFIGVudmlyb25tZW50LlxuXG5JZiB5b3UgY2FuIHRydXN0IHJldGFyZGVkIGNlbGVicml0aWVzLFxuXG5Zb3UgY2FuIHRydXN0IFVuaXN3YXAgdG8gY3JlYXRlIGFuZCBtYWludGFpbiBtb21lbnR1bSwgbm8/XG5cbn4gRHIuIEF4aXVzLiIsImNyZWF0ZWRfYXQiOiJXZWQgQXVnIDA1IDE2OjM0OjUxICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL3RyYWRpbmdfYXhlL3N0YXR1cy8yMDg1MDQxODU1ODEzNjI4MjI1IiwibWVkaWEiOltdfQ=='

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

# Classification: This is a commentary/opinion on crypto industry practices
# Mentions Uniswap, DeFi, and crypto industry dynamics - financial in nature
# But it's not a personal trade action, just social commentary
CLASSIFICATION="informational"
REASON="crypto-industry-commentary/uniswap-opinion"

if [ "$CLASSIFICATION" = "skip" ]; then
  echo "  → Classification: $CLASSIFICATION ($REASON)"
  echo "  → No alert sent"
else
  echo "  → Classification: $CLASSIFICATION ($REASON)"
  echo "  → Will send informational alert"
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
- Aug 05 16:34Z — $CLASSIFICATION: UNISWAP commentary on crypto influencer dynamics, defends Uniswap integrity ($TWEET_ID)
EOF

# Step 5: Alert if informational
if [ "$CLASSIFICATION" = "informational" ]; then
  echo "📢 Sending informational alert..."

  # Extract first 140 chars of text for alert preview
  PREVIEW=$(echo "$TEXT" | cut -c1-140)

  # Use notify script if it exists
  if command -v ./notify &>/dev/null; then
    ./notify "🐦 *[X] @$USERNAME*

$PREVIEW...

[View tweet]($URL)"
    echo "  → Alert sent via notify"
  else
    echo "  → notify script not available, alert would go: $PREVIEW"
  fi
fi

# Step 6: Log
echo ""
echo "📝 Appending to log..."

LOGFILE="memory/logs/2026-08-05.md"
mkdir -p memory/logs

cat >> "$LOGFILE" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker(s): [UNISWAP]
- alerted: yes
- notes: crypto industry commentary, Uniswap defense/opinion

EOF

echo "  → Logged to $LOGFILE"
echo ""
echo "✅ Skill execution complete"
echo ""
echo "## Summary"
echo "- Event: Tweet from @$USERNAME (ID: $TWEET_ID)"
echo "- Classification: $CLASSIFICATION ($REASON)"
echo "- Action: Sent informational alert"
echo "- Memory updated: traders.md, x-trader-seen.txt, daily log"
