#!/usr/bin/env bash
# prefetch-discord-traders.sh
# Runs BEFORE Claude starts. Fetches messages from watched Discord channels via REST API.
# Called by AEON's workflow: ./scripts/prefetch-*.sh <skill_name> <var>
# Only activates for the discord-trader-monitor skill.
#
# Uses your Discord user token (DISCORD_USER_TOKEN) to call Discord's REST API.
# Fetches ALL recent messages (not filtered by user) so Claude has full context
# including member questions that traders are responding to.
#
# Required GitHub Secret:
#   DISCORD_USER_TOKEN — your Discord user token

set -euo pipefail

SKILL="${1:-}"
[ "$SKILL" = "discord-trader-monitor" ] || exit 0

if [ -z "${DISCORD_USER_TOKEN:-}" ]; then
  echo "prefetch-discord-traders: DISCORD_USER_TOKEN not set, skipping"
  exit 0
fi

mkdir -p .xai-cache

# Read channel list from config file
CONFIG_FILE="memory/discord-channels.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "prefetch-discord-traders: $CONFIG_FILE not found, skipping"
  exit 0
fi

CHANNEL_IDS=$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
print(','.join(config['all_channel_ids']))
" 2>/dev/null)

if [ -z "$CHANNEL_IDS" ]; then
  echo "prefetch-discord-traders: no channel IDs found in config"
  exit 0
fi

IFS=',' read -ra CHANNELS <<< "$CHANNEL_IDS"
echo "prefetch-discord-traders: fetching from ${#CHANNELS[@]} channels"

RESULTS="[]"

for CHANNEL_ID in "${CHANNELS[@]}"; do
  CHANNEL_ID=$(echo "$CHANNEL_ID" | tr -d ' ')
  [ -z "$CHANNEL_ID" ] && continue

  echo "  channel $CHANNEL_ID..."

  # Fetch last 50 messages from channel (includes all users for context)
  MSGS_RESP=$(curl -sf \
    -H "Authorization: $DISCORD_USER_TOKEN" \
    -H "Content-Type: application/json" \
    "https://discord.com/api/v10/channels/$CHANNEL_ID/messages?limit=50" 2>/dev/null) || {
    echo "  warning: failed to fetch channel $CHANNEL_ID (check token or channel access)"
    continue
  }

  # Check for Discord error response
  IS_ERROR=$(echo "$MSGS_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    # Discord errors return an object, message list returns an array
    print('error' if isinstance(d, dict) and 'code' in d else 'ok')
except:
    print('error')
" 2>/dev/null || echo "error")

  if [ "$IS_ERROR" = "error" ]; then
    ERROR_MSG=$(echo "$MSGS_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('message','unknown'))" 2>/dev/null || echo "unknown")
    echo "  warning: Discord API error for channel $CHANNEL_ID: $ERROR_MSG"
    continue
  fi

  # Parse messages — include ALL messages (not just trader), preserve author info for context
  CHANNEL_MSGS=$(echo "$MSGS_RESP" | python3 -c "
import json, sys, datetime

channel_id = '$CHANNEL_ID'
cutoff = datetime.datetime.utcnow() - datetime.timedelta(hours=24)

try:
    messages = json.load(sys.stdin)
    result = []
    for msg in messages:
        # Skip empty messages (images only, etc.)
        content = msg.get('content', '').strip()
        if not content:
            continue
        # Parse timestamp
        try:
            ts_str = msg.get('timestamp', '')
            ts = datetime.datetime.fromisoformat(ts_str.replace('Z','+00:00')).replace(tzinfo=None)
            if ts < cutoff:
                continue
        except Exception:
            pass
        author = msg.get('author', {})
        # Flag if this message is a reply (has referenced_message)
        ref = msg.get('referenced_message')
        ref_content = ''
        ref_author = ''
        if ref:
            ref_content = ref.get('content', '').strip()[:200]  # truncate long replies
            ref_author = ref.get('author', {}).get('username', '')
        result.append({
            'id': msg['id'],
            'username': author.get('username', 'unknown'),
            'user_id': author.get('id', ''),
            'channel_id': channel_id,
            'text': content,
            'created_at': msg.get('timestamp', ''),
            'is_reply': ref is not None,
            'reply_to_username': ref_author,
            'reply_to_text': ref_content
        })
    print(json.dumps(result))
except Exception as e:
    print('[]')
    print(f'parse error: {e}', file=sys.stderr)
" 2>/dev/null) || CHANNEL_MSGS="[]"

  MSG_COUNT=$(echo "$CHANNEL_MSGS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  echo "  channel $CHANNEL_ID: $MSG_COUNT messages"

  # Merge into results
  RESULTS=$(python3 -c "
import json
existing = json.loads('''$RESULTS''')
new_msgs = json.loads('''$CHANNEL_MSGS''')
print(json.dumps(existing + new_msgs))
" 2>/dev/null || echo "$RESULTS")

  # Small delay to avoid Discord rate limiting
  sleep 0.5
done

# Save full cache (all messages, all channels)
echo "$RESULTS" > .xai-cache/discord-traders.json

TOTAL=$(echo "$RESULTS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
echo "prefetch-discord-traders: saved $TOTAL total messages to .xai-cache/discord-traders.json"
