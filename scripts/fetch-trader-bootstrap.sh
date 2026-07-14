#!/usr/bin/env bash
#
# Fetch — Trader Bootstrap (one-time lookback, X + Discord; LOOKBACK_DAYS, default 3)
#
# Invoked BY the `trader-bootstrap` skill (inside the sandbox), replacing the
# old prefetch-trader-bootstrap.sh workflow stage. Auth goes through
# ./secretcurl, which substitutes {TWITTERAPI_IO_KEY} / {DISCORD_USER_TOKEN}
# placeholders internally — secrets never appear on a command line. Both keys
# are injected per-skill from the `requires:` frontmatter (least privilege).
#
# Output:
#   .xai-cache/trader-bootstrap-x.json        — array of tweets, oldest first
#   .xai-cache/trader-bootstrap-discord.json  — array of Discord messages, oldest first

set -uo pipefail

# secretcurl is copied to repo root by the workflow; fall back to the committed
# script for local runs.
SC="./secretcurl"
[ -x "$SC" ] || SC="bash scripts/secretcurl.sh"

MISSING=""
[ -z "${TWITTERAPI_IO_KEY:-}" ] && MISSING="$MISSING TWITTERAPI_IO_KEY"
[ -z "${DISCORD_USER_TOKEN:-}" ] && MISSING="$MISSING DISCORD_USER_TOKEN"
if [ -n "$MISSING" ]; then
  echo "fetch-trader-bootstrap: missing:${MISSING} (declare in the skill's requires: frontmatter)" >&2
  exit 1
fi

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

# Lookback window (days). Override via env: LOOKBACK_DAYS=7 ./scripts/fetch-trader-bootstrap.sh
LOOKBACK_DAYS="${LOOKBACK_DAYS:-3}"
LOOKBACK_TS=$(date -u -d "${LOOKBACK_DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"${LOOKBACK_DAYS}"d +%Y-%m-%dT%H:%M:%SZ)

# ── X via twitterapi.io REST ──────────────────────────────────────────────────
# twitterapi.io does not support a "since" param — paginate and stop when
# tweets fall outside the lookback window. Response shape is
# { status: "success", data: { tweets: [...], next_cursor } } and tweet
# createdAt strings are unreliable, so the cutoff uses snowflake IDs
# (same approach as fetch-trader-x-bootstrap.sh — the verified-correct parser).

NOW_S=$(date +%s)
CUTOFF_MS=$(( (NOW_S - LOOKBACK_DAYS * 86400) * 1000 ))
CUTOFF_SNOWFLAKE=$(( (CUTOFF_MS - 1288834974657) * 4194304 ))
MAX_PAGES=$(( LOOKBACK_DAYS * 2 ))
[ "$MAX_PAGES" -lt 5 ] && MAX_PAGES=5

echo "Fetching ${LOOKBACK_DAYS}-day X history for: ${WATCHED_X_ACCOUNTS}"

X_RESULTS="[]"
IFS=',' read -ra ACCOUNTS <<< "$WATCHED_X_ACCOUNTS"
for handle in "${ACCOUNTS[@]}"; do
  cursor=""
  handle_tweets="[]"
  pages=0

  while [ $pages -lt $MAX_PAGES ]; do
    URL="https://api.twitterapi.io/twitter/user/last_tweets?userName=${handle}"
    [ -n "$cursor" ] && URL="${URL}&cursor=${cursor}"

    RESP=$($SC -s --max-time 15 -H 'x-api-key: {TWITTERAPI_IO_KEY}' "$URL" || echo "")
    if [ -z "$RESP" ]; then
      echo "  WARN: empty response for @${handle} (curl failed or timeout)"
      break
    fi

    # Check for API-level error
    STATUS=$(echo "$RESP" | jq -r '.status // ""' 2>/dev/null || true)
    if [ "$STATUS" != "success" ]; then
      echo "  API ERROR for @${handle}: $(echo "$RESP" | jq -r '.msg // .message // .error // "unknown"' 2>/dev/null)"
      echo "  RAW: $(echo "$RESP" | head -c 300)"
      break
    fi

    # Extract tweets from correct path: .data.tweets[]
    TWEET_COUNT=$(echo "$RESP" | jq '.data.tweets | length' 2>/dev/null || echo "0")
    if [ "$TWEET_COUNT" = "0" ]; then
      echo "  @${handle}: no tweets on page $((pages+1)), stopping"
      break
    fi

    # Take tweets whose snowflake ID is above cutoff (newer than the window)
    PAGE_TWEETS=$(echo "$RESP" | jq -c --argjson cutoff "$CUTOFF_SNOWFLAKE" '[
      .data.tweets[]? |
      select((.id | tonumber) > $cutoff) |
      {
        id: .id,
        username: .author.userName,
        text: .text,
        created_at: (.createdAt // .created_at // ""),
        url: (.url // ("https://x.com/" + .author.userName + "/status/" + .id)),
        media: ([.media[]?.media_url_https? // empty] // [])
      }
    ]' 2>/dev/null || echo "[]")

    PAGE_COUNT=$(echo "$PAGE_TWEETS" | jq 'length' 2>/dev/null || echo "0")
    handle_tweets=$(echo "$handle_tweets $PAGE_TWEETS" | jq -s 'add // []')

    # If fewer tweets passed the cutoff than were on the page, we've gone back far enough
    if [ "$PAGE_COUNT" -lt "$TWEET_COUNT" ]; then
      break
    fi

    # Get next cursor
    cursor=$(echo "$RESP" | jq -r '.data.next_cursor // .next_cursor // .nextCursor // ""' 2>/dev/null || true)
    [ -z "$cursor" ] && break

    pages=$((pages + 1))
    sleep 1
  done

  echo "  @${handle}: $(echo "$handle_tweets" | jq 'length') tweets"
  X_RESULTS=$(echo "$X_RESULTS $handle_tweets" | jq -s 'add')
  sleep 1
done

# Sort oldest → newest (by snowflake ID — createdAt strings are unreliable)
echo "$X_RESULTS" | jq 'sort_by(.id | tonumber)' > .xai-cache/trader-bootstrap-x.json
echo "X cache written: $(echo "$X_RESULTS" | jq 'length') tweets"

# ── Discord REST ──────────────────────────────────────────────────────────────

echo "Fetching ${LOOKBACK_DAYS}-day Discord history across ${#DISCORD_CHANNELS[@]} channels"

DISCORD_RESULTS="[]"
for entry in "${DISCORD_CHANNELS[@]}"; do
  IFS=':' read -r channel_id trader chan_type <<< "$entry"

  before=""
  chan_pages=0
  while [ $chan_pages -lt 5 ]; do
    URL="https://discord.com/api/v10/channels/${channel_id}/messages?limit=100"
    [ -n "$before" ] && URL="${URL}&before=${before}"

    RESP=$($SC -s -H 'Authorization: {DISCORD_USER_TOKEN}' "$URL" || echo "")
    [ -z "$RESP" ] && break

    MSG_COUNT=$(echo "$RESP" | jq 'length' 2>/dev/null || echo "0")
    [ "$MSG_COUNT" = "0" ] && break

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

    # Stop paginating once the oldest message on the page falls outside the window
    OLDEST_TS=$(echo "$RESP" | jq -r '[.[].timestamp] | min // ""' 2>/dev/null || true)
    if [ -z "$OLDEST_TS" ] || [ "$OLDEST_TS" \< "$LOOKBACK_TS" ]; then
      break
    fi

    before=$(echo "$RESP" | jq -r 'min_by(.timestamp) | .id // ""' 2>/dev/null || true)
    [ -z "$before" ] && break

    chan_pages=$((chan_pages + 1))
    sleep 1
  done
  sleep 1
done

# Sort oldest → newest
echo "$DISCORD_RESULTS" | jq 'sort_by(.created_at)' > .xai-cache/trader-bootstrap-discord.json
echo "Discord cache written: $(echo "$DISCORD_RESULTS" | jq 'length') messages"

echo "Bootstrap fetch complete."
