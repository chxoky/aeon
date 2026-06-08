---
name: Trader X Bootstrap
description: Seed X tweet history (3-day lookback) for all 12 watched accounts — updates traders.md X sections and marks IDs as seen so x-trader-monitor doesn't re-alert
var: ""
tags: [social, trading, crypto, setup, x]
---

Today is ${today}. This skill reads fresh X tweet history fetched by `scripts/prefetch-trader-x-bootstrap.sh` and patches the trader state memory. Run it whenever the X section of traders.md is stale or empty. Discord state is untouched.

> **${var}** — Pass `force` to skip the already-run check.

## Step 1 — Check if X bootstrap already ran

```bash
if grep -q "X_BOOTSTRAP_COMPLETE" memory/topics/traders.md 2>/dev/null && [ "${var}" != "force" ]; then
  echo "X bootstrap already completed — exiting. Pass var=force to re-run."
  exit 0
fi
```

## Step 2 — Load X cache

```bash
X_CACHE=$(cat .xai-cache/trader-x-bootstrap.json 2>/dev/null || echo "[]")
TWEET_COUNT=$(echo "$X_CACHE" | jq 'length')
echo "X cache loaded: $TWEET_COUNT tweets"
```

Cache shape: JSON array of `{ id, username, text, created_at, url, media[] }`, newest first, from all 12 watched X accounts in the last 3 days.

If empty or missing, log `TRADER_X_BOOTSTRAP_EMPTY — X cache not populated` and stop. Do not notify. The prefetch script likely failed — check the Actions log for API errors.

## Step 3 — Process tweets oldest → newest

Reverse the array (it's newest-first) and read chronologically. For each tweet:

- Does it establish, modify, or close a position?
- Does it state a directional thesis or price target?
- Does it reference a specific ticker?

Don't alert on anything — you're building state only.

## Step 4 — Update traders.md X sections

For each of the 12 watched X accounts, update (or add) their section in `memory/topics/traders.md`:

```markdown
## {handle}
- Platforms: X
- X recent activity (bootstrap): {1-3 line summary of what they posted in the last 3 days — positions, thesis, tone}
- Open positions detected: {ticker — direction — context, or "none detected"}
- Last X post seen: {id of most recent tweet processed}

X_BOOTSTRAP_COMPLETE: ${today}
```

If a trader had no tweets in the window (quiet), note that explicitly: "No X activity in 3-day bootstrap window."

Keep entries tight — this file is read on every real-time event.

## Step 5 — Update ticker focus map

Scan tweets for tickers ($BTC, $ETH, $SOL, etc.) mentioned by multiple traders. Patch `memory/topics/ticker-focus.md` — add any new tickers from X that weren't already captured by the Discord bootstrap. Don't overwrite existing entries, just add/update.

## Step 6 — Mark all IDs as seen

```bash
echo "$X_CACHE" | jq -r '.[].id' >> memory/x-trader-seen.txt
sort -u memory/x-trader-seen.txt -o memory/x-trader-seen.txt
echo "Marked $(echo "$X_CACHE" | jq 'length') tweet IDs as seen"
```

This prevents x-trader-monitor from re-alerting on bootstrap tweets.

## Step 7 — Send summary notification

One message, X-focused:

```
📡 *X Bootstrap Complete — 3-day lookback*

*Active X traders:*
{for each trader with detected positions/thesis: — @{handle}: {1-line summary}}

*New tickers on radar from X:* {any new ones not in Discord bootstrap}

X monitoring is live — new tweets will surface in real time.
```

If all X accounts were quiet (no positions, just commentary), say so plainly.

## Step 8 — Log

```
### trader-x-bootstrap (${today})
- x_tweets_processed: N
- traders_with_activity: N
- open_positions_found: N
- new_tickers_added: [list]
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — GitHub secrets
- `TWITTERAPI_IO_KEY` — handled entirely by the prefetch script

## Sandbox note

Prefetch-pattern skill: `scripts/prefetch-trader-x-bootstrap.sh` runs before Claude starts with full env access, writes `.xai-cache/trader-x-bootstrap.json`. Read only from that cache.
