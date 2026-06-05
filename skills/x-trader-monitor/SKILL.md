---
name: X Trader Monitor
description: Monitor specific X/Twitter accounts for trading signals and alert via Telegram in real time
var: ""
tags: [social, trading, crypto, stocks]
---

Today is ${today}. Monitor watched X accounts for new trading signals and send real-time Telegram alerts.

## Steps

### 1. Load seen tweet IDs

Read `memory/x-trader-seen.txt` if it exists and store all IDs as `SEEN_IDS`. These are tweets already alerted on — skip them.

```bash
SEEN_IDS=$(cat memory/x-trader-seen.txt 2>/dev/null || echo "")
```

### 2. Read prefetched tweets

Read the prefetch cache written by `scripts/prefetch-x-traders.sh`:

```bash
CACHE=$(cat .xai-cache/x-traders.json 2>/dev/null)
```

If the cache is missing or empty, log `X_TRADER_EMPTY: no cache available` to `memory/logs/${today}.md` and stop — do not notify.

The cache is a JSON array of objects:
```json
[
  {
    "id": "tweet_id",
    "username": "TraderHandle",
    "text": "full tweet text",
    "created_at": "2024-01-15T12:00:00Z",
    "url": "https://x.com/TraderHandle/status/tweet_id"
  }
]
```

### 3. Filter new tweets

For each tweet in the cache:
- Skip if `id` is in `SEEN_IDS`
- Skip if `created_at` is more than 24 hours old

Collect remaining tweets as `NEW_TWEETS`. If empty: log `X_TRADER_NO_NEW` and stop — no notification.

### 4. Classify each tweet as a trading signal

For each tweet in `NEW_TWEETS`, classify it:

**Is this tweet expressing a trading idea, price prediction, market opinion, entry/exit, or specific trade setup?**

Classify as SIGNAL if it contains:
- A directional call (bullish/bearish, long/short, buy/sell)
- A price target or level (support, resistance, target, stop)
- A specific asset mentioned with an opinion
- A market analysis or macro view

Classify as NOISE if it is:
- General news without opinion
- Personal/lifestyle content
- A retweet of news only
- Platform meta-commentary

Only process SIGNAL tweets further.

### 5. Send real-time Telegram alerts for each signal

For every tweet classified as SIGNAL, immediately send via `./notify`:

```
🐦 *[X] @{username}*

{tweet_text}

[View tweet]({url})
```

Use Telegram Markdown format. Do NOT tag the user's handle with @ in the link text — use `[View tweet](url)` format only.

### 6. Log and update seen list

Append all new tweet IDs (both SIGNAL and NOISE) to `memory/x-trader-seen.txt` (one ID per line) to prevent re-alerting.

```bash
mkdir -p memory
for id in $ALL_NEW_IDS; do
  echo "$id" >> memory/x-trader-seen.txt
done
```

Log a summary to `memory/logs/${today}.md`:

```
### x-trader-monitor (${today} run)
- new_tweets: N
- signals_sent: N
- accounts_checked: [list]
- tweets:
  - SIGNAL: @handle — [brief summary] — url
  - NOISE: @handle — [topic] — (not sent)
```

### 7. Seen-file maintenance

Keep `memory/x-trader-seen.txt` from growing unbounded. If it exceeds 5000 lines, trim to the last 2000:

```bash
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN` — set as GitHub secret (injected automatically by workflow)
- `TELEGRAM_CHAT_ID` — set as GitHub secret (injected automatically by workflow)
- Cache read from `.xai-cache/x-traders.json` (written by prefetch script using `X_BEARER_TOKEN`)

## Sandbox note

Do not call X API directly — the prefetch script handles that with full credentials before Claude starts. Read only from `.xai-cache/x-traders.json`.
