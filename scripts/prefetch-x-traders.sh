#!/usr/bin/env bash
# prefetch-x-traders.sh
# Runs BEFORE Claude starts. Fetches tweets from watched X accounts via X API v2.
# Called by AEON's workflow: ./scripts/prefetch-*.sh <skill_name> <var>
# Only activates for the x-trader-monitor skill.

set -euo pipefail

SKILL="${1:-}"
# Only run for our skill
[ "$SKILL" = "x-trader-monitor" ] || exit 0

# Check required env vars
if [ -z "${X_BEARER_TOKEN:-}" ]; then
  echo "prefetch-x-traders: X_BEARER_TOKEN not set, skipping"
  exit 0
fi

if [ -z "${WATCHED_X_ACCOUNTS:-}" ]; then
  echo "prefetch-x-traders: WATCHED_X_ACCOUNTS not set, skipping"
  exit 0
fi

mkdir -p .xai-cache

echo "prefetch-x-traders: fetching tweets for accounts: $WATCHED_X_ACCOUNTS"

# Convert comma-separated accounts to array
IFS=',' read -ra ACCOUNTS <<< "$WATCHED_X_ACCOUNTS"

RESULTS="[]"
# Look back 24 hours; seen-file deduplication prevents re-alerting
START_TIME=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)
echo "prefetch-x-traders: start_time=$START_TIME"

for ACCOUNT in "${ACCOUNTS[@]}"; do
  ACCOUNT=$(echo "$ACCOUNT" | tr -d ' @')
  [ -z "$ACCOUNT" ] && continue

  echo "  fetching @$ACCOUNT..."

  # Step 1: Get user ID from username
  USER_RESP=$(curl -s \
    -H "Authorization: Bearer $X_BEARER_TOKEN" \
    "https://api.twitter.com/2/users/by/username/$ACCOUNT") || {
    echo "  warning: curl failed for @$ACCOUNT"
    continue
  }
  echo "  user_resp for @$ACCOUNT: $(echo "$USER_RESP" | head -c 200)"

  USER_ID=$(echo "$USER_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['id'])" 2>/dev/null) || {
    echo "  warning: could not parse user ID for @$ACCOUNT"
    continue
  }

  # Step 2: Get recent tweets (exclude retweets and replies, max 10)
  TWEETS_RESP=$(curl -sf \
    -H "Authorization: Bearer $X_BEARER_TOKEN" \
    "https://api.twitter.com/2/users/$USER_ID/tweets?max_results=10&tweet.fields=created_at,text&exclude=retweets,replies&start_time=$START_TIME" 2>/dev/null) || {
    echo "  warning: failed to fetch tweets for @$ACCOUNT"
    continue
  }

  # Parse tweets and append to results
  ACCOUNT_TWEETS=$(echo "$TWEETS_RESP" | python3 -c "
import json, sys
username = '$ACCOUNT'
user_id = '$USER_ID'
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
            'url': f'https://x.com/{username}/status/{t[\"id\"]}'
        })
    print(json.dumps(result))
except Exception as e:
    print('[]')
    print(f'parse error: {e}', file=sys.stderr)
" 2>/dev/null) || ACCOUNT_TWEETS="[]"

  TWEET_COUNT=$(echo "$ACCOUNT_TWEETS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  echo "  @$ACCOUNT: $TWEET_COUNT new tweets"

  # Merge into results
  RESULTS=$(python3 -c "
import json, sys
existing = json.loads('$RESULTS')
new = json.loads('''$ACCOUNT_TWEETS''')
print(json.dumps(existing + new))
" 2>/dev/null || echo "$RESULTS")

  # Rate limit: X API v2 allows ~15 req/15min per user
  sleep 1
done

# Save cache
echo "$RESULTS" > .xai-cache/x-traders.json

TOTAL=$(echo "$RESULTS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
echo "prefetch-x-traders: saved $TOTAL total tweets to .xai-cache/x-traders.json"
