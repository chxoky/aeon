#!/usr/bin/env bash
#
# Fetch — Trader X Bootstrap (X-only, LOOKBACK_DAYS lookback, default 3)
#
# Invoked BY the `trader-x-bootstrap` skill (inside the sandbox), replacing the
# old prefetch-trader-x-bootstrap.sh workflow stage. Auth goes through
# ./secretcurl, which substitutes the {TWITTERAPI_IO_KEY} placeholder
# internally — the secret never appears on a command line. The key itself is
# injected per-skill from the `requires:` frontmatter (least privilege).
#
# twitterapi.io response shape:
#   { "status": "success", "data": { "tweets": [...], "next_cursor": "..." } }
# Tweets do NOT have a reliable createdAt string — we stop pagination by
# snowflake ID (tweet IDs encode timestamp; lower ID = older tweet).
#
# Output:
#   .xai-cache/trader-x-bootstrap.json  — array of tweets, newest first

set -uo pipefail

# secretcurl is copied to repo root by the workflow; fall back to the committed
# script for local runs.
SC="./secretcurl"
[ -x "$SC" ] || SC="bash scripts/secretcurl.sh"

if [ -z "${TWITTERAPI_IO_KEY:-}" ]; then
  echo "fetch-trader-x-bootstrap: TWITTERAPI_IO_KEY not set (declare it in the skill's requires: frontmatter)" >&2
  exit 1
fi

mkdir -p .xai-cache

WATCHED_X_ACCOUNTS="Bitcoin_Astro,abetrade,trading_axe,KillaXBT,Crypto_Chase,HeartCanHodl,t_in_crypto,ryzzqq,swarmister,bull_genius,Stoiiic,Wild_Randomness"

# Lookback window (days). Override via env: LOOKBACK_DAYS=7 ./scripts/fetch-trader-x-bootstrap.sh
LOOKBACK_DAYS="${LOOKBACK_DAYS:-3}"

# Cutoff: snowflake ID corresponding to ~LOOKBACK_DAYS ago
# Twitter snowflake: (timestamp_ms - 1288834974657) << 22
NOW_S=$(date +%s)
CUTOFF_MS=$(( (NOW_S - LOOKBACK_DAYS * 86400) * 1000 ))
CUTOFF_SNOWFLAKE=$(( (CUTOFF_MS - 1288834974657) * 4194304 ))

# Pagination cap scales with the window (~20 tweets/page)
MAX_PAGES=$(( LOOKBACK_DAYS * 2 ))
[ "$MAX_PAGES" -lt 5 ] && MAX_PAGES=5

echo "Fetching X history for: ${WATCHED_X_ACCOUNTS}"
echo "Cutoff snowflake ID: ${CUTOFF_SNOWFLAKE} (~${LOOKBACK_DAYS} days ago)"

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
      echo "  WARN: empty response for @${handle} (curl timeout or network error)"
      break
    fi

    # Check for API-level error
    STATUS=$(echo "$RESP" | jq -r '.status // ""' 2>/dev/null || true)
    if [ "$STATUS" != "success" ]; then
      echo "  API ERROR for @${handle}: $(echo "$RESP" | jq -r '.msg // .message // .error // "unknown"' 2>/dev/null)"
      echo "  RAW: $(echo "$RESP" | head -c 200)"
      break
    fi

    # Extract tweets from correct path: .data.tweets[]
    TWEET_COUNT=$(echo "$RESP" | jq '.data.tweets | length' 2>/dev/null || echo "0")
    if [ "$TWEET_COUNT" = "0" ]; then
      echo "  @${handle}: no tweets on page $((pages+1)), stopping"
      break
    fi

    # Take tweets whose snowflake ID is above cutoff (i.e. newer than the window)
    # Also normalize fields into our standard shape
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

  COUNT=$(echo "$handle_tweets" | jq 'length' 2>/dev/null || echo "0")
  echo "  @${handle}: ${COUNT} tweets"
  X_RESULTS=$(echo "$X_RESULTS $handle_tweets" | jq -s 'add // []')
  sleep 1
done

# Sort newest first (by snowflake ID, descending — higher ID = newer)
TOTAL=$(echo "$X_RESULTS" | jq 'length')
echo "$X_RESULTS" | jq 'sort_by(.id | tonumber) | reverse' > .xai-cache/trader-x-bootstrap.json
echo "X cache written: ${TOTAL} tweets → .xai-cache/trader-x-bootstrap.json"
