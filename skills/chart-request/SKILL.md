---
name: Chart Request
description: Listens for Telegram messages matching `chart $TICKER [timeframe] [indicator]` and replies with a rendered candlestick chart image
var: ""
tags: [trading, crypto, stocks, telegram, charts]
---

Today is ${today}. You are triggered every minute. Your job: read pending Telegram chart requests from the prefetch cache, validate and parse each one, and write a job spec for the postprocess script to render and deliver the chart.

## Step 1 — Check for pending requests

Read `.xai-cache/chart-request-messages.json`. If the file is missing or the array is empty, log `chart-request: no pending messages` and stop — no notify, no output.

```bash
cat .xai-cache/chart-request-messages.json 2>/dev/null || echo "[]"
```

## Step 2 — Parse each chart request

For each message in the array, parse the command. Expected format (case-insensitive):
```
chart $TICKER [TIMEFRAME] [INDICATOR]
```

**TICKER** (required): e.g. `$ZEC`, `$BTC`, `$NVDA`, `$AAPL`. Strip the leading `$`.

**TIMEFRAME** (optional, default `1D`): one of `1m`, `5m`, `15m`, `30m`, `1h`, `4h`, `1D`, `1W`, `1M`.

**INDICATOR** (optional, default `EMA50`): format `{TYPE}{PERIOD}` where TYPE is `EMA` or `SMA` and PERIOD is a positive integer. Examples: `EMA50`, `SMA20`, `EMA200`. Pass `none` to omit.

Map timeframe → yfinance params:

| Timeframe | yf_period | yf_interval |
|-----------|-----------|-------------|
| 1m        | 1d        | 1m          |
| 5m        | 5d        | 5m          |
| 15m       | 5d        | 15m         |
| 30m       | 5d        | 30m         |
| 1h        | 14d       | 1h          |
| 4h        | 30d       | 1h          |
| 1D        | 90d       | 1d          |
| 1W        | 730d      | 1wk         |
| 1M        | 1825d     | 1mo         |

Note: yfinance has no 4h interval — use 1h data and let the chart show 1h candles over 30 days.

**Ticker → yfinance symbol:**
- Crypto tickers (ZEC, BTC, ETH, SOL, HYPE, AVAX, MATIC, XRP, ADA, DOT, LINK, UNI, DOGE, LTC, BCH, etc.): append `-USD`. E.g. `ZEC` → `ZEC-USD`.
- Traditional tickers (NVDA, AAPL, SPY, QQQ, GLD, etc.): use as-is.
- If ambiguous, default to appending `-USD` (crypto assumption). Claude should use context from `memory/topics/ticker-focus.md` if available.

## Step 3 — Validate and write job specs

For each valid request, create a JSON file at `.pending-chart-request/chart-{message_id}.json`:

```json
{
  "message_id": 12345,
  "chat_id": -1001234567890,
  "ticker": "ZEC",
  "yf_ticker": "ZEC-USD",
  "timeframe": "1D",
  "yf_period": "90d",
  "yf_interval": "1d",
  "ma_type": "EMA",
  "ma_period": 50,
  "requested_by": "username",
  "original_text": "chart $ZEC 1D EMA50"
}
```

If `INDICATOR` is `none` or omitted, set `ma_type` to `null` and `ma_period` to `null`.

Skip files that already exist (already queued from a prior run).

For invalid requests (unrecognized format, unsupported timeframe, bad indicator syntax):
- Do not write a job spec.
- Reply via Telegram directly using the `./notify` mechanism is not available for direct replies — instead write an error spec to `.pending-chart-request/error-{message_id}.json`:

```json
{
  "message_id": 12345,
  "chat_id": -1001234567890,
  "error": "Could not parse chart request. Format: chart $TICKER [1D] [EMA50]",
  "original_text": "chart blah"
}
```

## Step 4 — Log

Append to `memory/logs/${today}.md`:

```
### chart-request
- messages_checked: N
- charts_queued: N
- errors: N
- tickers: [list]
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — fetched and polled in prefetch step; not needed here.

## Sandbox note

All Telegram I/O and chart rendering happen in the pre/post-process scripts. This skill only reads cache and writes job specs — no outbound network calls needed.
