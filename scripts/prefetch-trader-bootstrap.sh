#!/usr/bin/env bash
#
# Prefetch — Trader Bootstrap (one-time 3-day lookback)
#
# Runs BEFORE Claude starts, with full env access. Fetches 3 days of history
# from twitterapi.io REST (X) and Discord REST, writes JSON caches that the
# `trader-bootstrap` skill reads. Credential separation: Claude never sees
# TWITTERAPI_IO_KEY or DISCORD_USER_TOKEN directly.
#
# Required env:
#   TWITTERAPI_IO_KEY   — twitterapi.io API key
#   DISCORD_USER_TOKEN  — Discord user token (REST auth header)
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

LOOKBACK_TS=$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-3d +%Y-%m-%dT%H:%M:%SZ)

# ── X via twitterapi.io REST ──────────────────────────────────────────────────

echo "Fetching 3-day X history for: ${WATCHED_X_ACCOUNTS}"

X_RESULTS="[]"
IFS=',' read -ra ACCOUNTS <<< "$WATCHED_X_ACCOUNTS"
for handle in "${ACCOUNTS[@]}"; do
  RESP=$(curl -s -H "x-api-key: ${TWITTERAPI_IO_KEY}" \
    "https://api.twitterapi.io/twitter/user/last_tweets?userName=${handle}&since=${LOOKBACK_TS}" || echo "")

  if [ -n "$RESP" ]; then
    PARSED=$(echo "$RESP" | jq -c '[.tweets[]? | {
      id: .id,
      username: .author.userName,
      text: .text,
      created_at: .createdAt,
      url: ("https://x.com/" + .author.userName + "/status/" + .id),
      media: [.media[]?.media_url_https? // empty]
    }]' 2>/dev/null || echo "[]")
    X_RESULTS=$(echo "$X_RESULTS $PARSED" | jq -s 'add')
  fi
  sleep 1  # gentle on rate limits across 12 accounts
done

# Sort oldest → newest
echo "$X_RESULTS" | jq 'sort_by(.created_at)' > .xai-cache/trader-bootstrap-x.json
echo "X cache written: $(echo "$X_RESULTS" | jq 'length') tweets"

# ── Discord REST ──────────────────────────────────────────────────────────────

echo "Fetching 3-day Discord history across ${#DISCORD_CHANNELS[@]} channels"

DISCORD_RESULTS="[]"
for entry in "${DISCORD_CHANNELS[@]}"; do
  IFS=':' read -r channel_id trader chan_type <<< "$entry"

  RESP=$(curl -s -H "Authorization: ${DISCORD_USER_TOKEN}" \
    "https://discord.com/api/v10/channels/${channel_id}/messages?limit=100" || echo "")

  if [ -n "$RESP" ]; then
    PARSED=$(echo "$RESP" | jq -c --arg cid "$channel_id" --arg cutoff "$LOOKBACK_TS" '[.[] | select(.timestamp > $cutoff) | {
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
