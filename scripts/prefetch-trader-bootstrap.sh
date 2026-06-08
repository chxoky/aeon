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
      "https://api.twitter.com/2/users/by/username/${handle}") || { echo "  warning: curl failed for @${handle}"; sleep 1; continue; }

    USER_ID=$(echo "$USER_RESP" | jq -r '.data.id // empty' 2>/dev/null) || true
    if [ -z "$USER_ID" ]; then
      echo "  warning: no user ID for @${handle}"
      sleep 1
      continue
    fi

    # Step 2: fetch up to 100 tweets since START_TIME (exclude retweets and replies)
    TWEETS_RESP=$(curl -s \
      -H "Authorization: Bearer ${X_BEARER_TOKEN}" \
      "https://api.twitter.com/2/users/${USER_ID}/tweets?max_results=100&tweet.fields=created_at,text&exclude=retweets,replies&start_time=${START_TIME}") || { echo "  warning: tweets fetch failed for @${handle}"; sleep 1; continue; }

    # Normalize to {id, username, text, created_at, url, media}
    PARSED=$(echo "$TWEETS_RESP" | jq -c --arg u "$handle" \
      '[.data[]? | {id: .id, username: $u, text: .text, created_at: .created_at, url: ("https://x.com/" + $u + "/status/" + .id), media: []}]' \
      2>/dev/null || echo "[]")

    COUNT=$(echo "$PARSED" | jq 'length' 2>/dev/null || echo 0)
    echo "  @${handle}: ${COUNT} tweets"

    # Merge using jq -s add (same pattern as Discord accumulation below)
    X_RESULTS=$(echo "$X_RESULTS $PARSED" | jq -s 'add' 2>/dev/null || echo "$X_RESULTS")

    sleep 1  # gentle on rate limits across 12 accounts
  done

  # Sort oldest → newest and write cache
  echo "$X_RESULTS" | jq 'sort_by(.created_at)' > .xai-cache/trader-bootstrap-x.json
  echo "X cache written: $(echo "$X_RESULTS" | jq 'length') tweets"
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
