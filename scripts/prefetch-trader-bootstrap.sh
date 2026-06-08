#!/usr/bin/env bash
#
# Prefetch — Trader Bootstrap (one-time 4-day lookback)
#
# Runs BEFORE Claude starts, with full env access. Fetches 4 days of history
# from Twitter API v2 (X) and Discord REST, writes JSON caches that the
# `trader-bootstrap` skill reads. Credential separation: Claude never sees
# X_BEARER_TOKEN or DISCORD_USER_TOKEN directly.
#
# Required env:
#   X_BEARER_TOKEN     — Twitter API v2 bearer token
#   DISCORD_USER_TOKEN — Discord user token (REST auth header)
#
# Output:
#   .xai-cache/trader-bootstrap-x.json        — array of tweets, oldest first
#   .xai-cache/trader-bootstrap-discord.json  — array of Discord messages, oldest first

set -uo pipefail

mkdir -p .xai-cache

WATCHED_X_ACCOUNTS="Bitcoin_Astro,abetrade,trading_axe,KillaXBT,Crypto_Chase,HeartCanHodl,t_in_crypto,ryzzqq,swarmister,bull_genius,Stoiiic,Wild_Randomness"

# Tracked Discord channels: trader → channel_id (mirrors CHANNEL_CONFIG in worker/src/index.js)
DISCORD_CHANNELS=(
  "1336082716063694962:Crypto_Chase:primary"
  "1343971265962049597:Crypto_Chase:supporting"
  "1247927786681794601:Crypto_Chase:supporting"
  "1411492188315193416:KillaXBT:primary"
  "1472153627324842057:HeartCanHodl:primary"
  "1191800982414299217:HeartCanHodl:primary"
  "1279738718680256553:HeartCanHodl:primary"
  "1393137051108507728:HeartCanHodl:primary"
  "1023638573313966212:HeartCanHodl:supporting"
)

START_TIME=$(date -u -d '4 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-4d +%Y-%m-%dT%H:%M:%SZ)

# ── X via Twitter API v2 ──────────────────────────────────────────────────────

if [ -z "${X_BEARER_TOKEN:-}" ]; then
  echo "X_BEARER_TOKEN not set — skipping X fetch"
  echo "[]" > .xai-cache/trader-bootstrap-x.json
else
  echo "Fetching 4-day X history for: ${WATCHED_X_ACCOUNTS} (start_time=${START_TIME})"

  X_RESULTS="[]"
  IFS=',' read -ra ACCOUNTS <<< "$WATCHED_X_ACCOUNTS"
  for handle in "${ACCOUNTS[@]}"; do
    handle=$(echo "$handle" | tr -d ' @')
    [ -z "$handle" ] && continue

    echo "  fetching @${handle}..."

    # Step 1: resolve username → user ID
    USER_RESP=$(curl -s \
      -H "Authorization: Bearer ${X_BEARER_TOKEN}" \
      "https://api.twitter.com/2/users/by/username/${handle}") || { echo "  warning: curl failed for @${handle}"; continue; }

    USER_ID=$(echo "$USER_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['id'])" 2>/dev/null) || { echo "  warning: no user ID for @${handle}"; continue; }

    # Step 2: fetch up to 100 tweets since START_TIME (exclude retweets and replies)
    TWEETS_RESP=$(curl -s \
      -H "Authorization: Bearer ${X_BEARER_TOKEN}" \
      "https://api.twitter.com/2/users/${USER_ID}/tweets?max_results=100&tweet.fields=created_at,text,attachments&exclude=retweets,replies&start_time=${START_TIME}") || { echo "  warning: tweets fetch failed for @${handle}"; continue; }

    ACCOUNT_TWEETS=$(echo "$TWEETS_RESP" | python3 -c "
import json, sys
username = '$handle'
try:
    data = json.load(sys.stdin)
    tweets = data.get('data', [])
    result = []
    for t in tweets:
        result.append({
            'id': t['id'],
            'username': username,
            'text': t['text'],
            'created_at': t.get('created_at', ''),
            'url': f'https://x.com/{username}/status/{t[\"id\"]}',
            'media': []
        })
    print(json.dumps(result))
except Exception as e:
    import sys as _sys; print(f'parse error: {e}', file=_sys.stderr)
    print('[]')
" 2>/dev/null) || ACCOUNT_TWEETS="[]"

    COUNT=$(echo "$ACCOUNT_TWEETS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
    echo "  @${handle}: ${COUNT} tweets"

    X_RESULTS=$(python3 -c "
import json, sys
existing = json.loads('''$X_RESULTS''')
new = json.loads('''$ACCOUNT_TWEETS''')
print(json.dumps(existing + new))
" 2>/dev/null || echo "$X_RESULTS")

    sleep 1  # gentle on rate limits across 12 accounts
  done

  # Sort oldest → newest
  echo "$X_RESULTS" | python3 -c "import json,sys; data=json.load(sys.stdin); data.sort(key=lambda x: x.get('created_at','')); print(json.dumps(data))" > .xai-cache/trader-bootstrap-x.json
  echo "X cache written: $(echo "$X_RESULTS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0) tweets"
fi

# ── Discord REST ──────────────────────────────────────────────────────────────

echo "Fetching 4-day Discord history across ${#DISCORD_CHANNELS[@]} channels"

DISCORD_RESULTS="[]"
for entry in "${DISCORD_CHANNELS[@]}"; do
  IFS=':' read -r channel_id trader chan_type <<< "$entry"

  RESP=$(curl -s -H "Authorization: ${DISCORD_USER_TOKEN}" \
    "https://discord.com/api/v10/channels/${channel_id}/messages?limit=100" || echo "")

  if [ -n "$RESP" ]; then
    PARSED=$(echo "$RESP" | jq -c --arg cid "$channel_id" --arg cutoff "$START_TIME" '[.[] | select(.timestamp > $cutoff) | {
      id: .id,
      channel_id: $cid,
      username: .author.username,
      content: .content,
      created_at: .timestamp,
      is_reply: (.referenced_message != null),
      referenced_message: (if .referenced_message then {username: .referenced_message.author.username, content: .referenced_message.content} else null end),
      attachments: [.attachments[]?.url? // empty]
    }]' 2>/dev/null || echo "[]")
    DISCORD_RESULTS=$(echo "$DISCORD_RESULTS $PARSED" | jq -s 'add')
  fi
  sleep 1
done

# Sort oldest → newest
echo "$DISCORD_RESULTS" | jq 'sort_by(.created_at)' > .xai-cache/trader-bootstrap-discord.json
echo "Discord cache written: $(echo "$DISCORD_RESULTS" | jq 'length') messages"

echo "Bootstrap prefetch complete."
