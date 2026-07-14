---
name: Trader Bootstrap
description: One-time 3-day lookback across all watched X accounts and Discord channels — builds initial trader state memory and sends a single founding summary
var: ""
tags: [social, trading, crypto, stocks, setup]
requires: [TWITTERAPI_IO_KEY, DISCORD_USER_TOKEN]
---

Today is ${today}. This is a **one-time setup skill** — run it once to seed memory before the real-time monitors (`x-trader-monitor`, `discord-trader-monitor`) take over. Running it again is harmless but wasteful (it re-marks already-seen IDs); don't schedule it recurring.

> **${var}** — Optional. Pass `force` to re-run even if `memory/topics/traders.md` already shows a completed bootstrap. Otherwise the skill checks first and exits if bootstrap already ran. You may also append a day count to set the lookback window, e.g. `force 7` for a 7-day lookback (default 3). If `${var}` contains a number, export it as `LOOKBACK_DAYS` before running the fetch script and read every "3 days" below as that window.

## Why this skill exists

The real-time monitors are reactive — they only know what's happened since they started watching. Without a bootstrap, Kyle would start with zero context: no sense of which traders currently hold positions, what their live theses are, or which tickers are already in play. This skill reads backward 3 days, reconstructs that state once, and hands the monitors a running start.

## Step 1 — Check if already run

```bash
if grep -q "BOOTSTRAP_COMPLETE" memory/topics/traders.md 2>/dev/null && [[ "${var}" != *force* ]]; then
  echo "Bootstrap already completed — exiting"
  exit 0
fi
```

If already complete and `${var}` doesn't contain `force`, log `TRADER_BOOTSTRAP_SKIPPED — already initialized` and stop. No notify.

## Step 2 — Fetch X + Discord history (lookback window)

Run the fetch script (it authenticates via `./secretcurl` using the per-skill
secrets declared in this file's `requires:` frontmatter — see Sandbox note),
then read both caches it writes:

```bash
LOOKBACK_DAYS="${LOOKBACK_DAYS:-3}" ./scripts/fetch-trader-bootstrap.sh
X_CACHE=$(cat .xai-cache/trader-bootstrap-x.json 2>/dev/null)
```

Shape: JSON array of `{ id, username, text, created_at, url, media }`, one entry per tweet from any of the 12 watched accounts in the last 3 days, **oldest first**.

If missing/empty, log `TRADER_BOOTSTRAP_X_EMPTY` and continue with Discord only — don't block the whole bootstrap on one platform.

## Step 3 — Read the Discord history cache

```bash
DISCORD_CACHE=$(cat .xai-cache/trader-bootstrap-discord.json 2>/dev/null)
```

Shape: JSON array of `{ id, channel_id, username, content, created_at, is_reply, referenced_message, attachments }`, oldest first, from all tracked channels (Crypto_Chase, KillaXBT, HeartCanHodl — see `memory/discord-channels.json`).

If missing/empty, log `TRADER_BOOTSTRAP_DISCORD_EMPTY` and continue with X only.

If BOTH caches are empty, log `TRADER_BOOTSTRAP_NO_DATA` and stop — do not write a partial/empty state file, do not notify.

## Step 4 — Merge and read chronologically, oldest → newest

Interleave both caches by `created_at` into one timeline. Read through it in order — this matters: a trader's later post often supersedes or closes out an earlier one (e.g. "longed NVDL at 45" followed three days later by "took profit on NVDL, +12%"). Reading newest-first would make you record a position as still-open when it's actually already closed.

For each item, lightly classify it (you don't need the full real-time decision tree here — just enough to build state):
- Does it establish, modify, or close a position?
- Does it state a thesis or directional view?
- Does it mention a ticker Kyle should track for overlap?

Don't alert on anything individually during this pass — you're building state, not generating real-time alerts. Suppress all per-item notifications.

## Step 5 — Build trader state memory

Write/overwrite `memory/topics/traders.md` with one section per watched trader (all 12 X + cross-reference the 3 Discord-tracked ones). For each:

```markdown
## {trader_handle}
- Platforms: X{ + Discord, channels: ... if applicable}
- Current open positions (as of bootstrap): {ticker — direction — entry context — order type if known}
- Recent thesis/posture: {1-3 lines summarizing where they stand right now}
- Conviction notes: {anything notable about how they communicate — useful for future ambiguity calibration}
- Last seen: {timestamp of most recent processed post}

BOOTSTRAP_COMPLETE: ${today}
```

Keep entries factual and compact — this file gets read on every single real-time event going forward, so bloat costs you context budget on every run.

## Step 6 — Build ticker focus map

Write `memory/topics/ticker-focus.md`:

```markdown
## Overlap tickers (mentioned by 2+ watched traders)
- {ticker}: mentioned by {traders}, current group lean: {bullish/bearish/mixed}

## Kyle's explicit watch list
- $HYPE
- $NVDA (traded as $NVDL on Kraken)
- $Gold (normalize: $GC, $XAUUSD, $GLD, $GOLD → treat as one)

## Quiet tickers (single-trader mentions, tracked silently)
- {ticker}: mentioned by {trader}, context: {one line}
```

## Step 7 — Mark all IDs as seen

Critical — this prevents the real-time monitors from re-alerting on everything you just processed:

```bash
mkdir -p memory
echo "$X_CACHE" | jq -r '.[].id' >> memory/x-trader-seen.txt
echo "$DISCORD_CACHE" | jq -r '.[].id' >> memory/discord-trader-seen.txt
sort -u memory/x-trader-seen.txt -o memory/x-trader-seen.txt
sort -u memory/discord-trader-seen.txt -o memory/discord-trader-seen.txt
```

## Step 8 — Send ONE founding summary

This is the only notification this skill sends — one message, covering everything live right now:

```
📋 *Trader Bootstrap Complete — {LOOKBACK_DAYS}-day lookback*

*Currently live setups/positions:*
{for each trader with an open position: — {handle}: {ticker} {direction}, {context}}

*Top overlap tickers:* {ranked list of 2-3}

*Notable theses to watch:* {1-2 line summary of the most actionable current views}

Real-time monitoring is now active — you'll hear about new developments as they happen.
```

If nothing is currently "live" (no open positions detected, just commentary), say so plainly rather than padding the message.

## Step 9 — Log

```
### trader-bootstrap (${today})
- x_tweets_processed: N
- discord_messages_processed: N
- traders_initialized: 12 (X) + 3 (Discord cross-ref)
- open_positions_found: N
- overlap_tickers: [list]
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — GitHub secrets
- `TWITTERAPI_IO_KEY`, `DISCORD_USER_TOKEN` — injected per-skill from this file's `requires:` frontmatter; used only inside `scripts/fetch-trader-bootstrap.sh` via `./secretcurl`

## Sandbox note

This is a **secretcurl-pattern skill** (upstream v0.1 model): run `./scripts/fetch-trader-bootstrap.sh` yourself in Step 2. It authenticates through `./secretcurl`, which substitutes `{TWITTERAPI_IO_KEY}` / `{DISCORD_USER_TOKEN}` placeholders internally so secrets never appear on a command line, and writes `.xai-cache/trader-bootstrap-x.json` and `.xai-cache/trader-bootstrap-discord.json`. Read from those caches — never call the APIs directly with raw `$SECRET` expansions (the permission analyzer blocks them).
