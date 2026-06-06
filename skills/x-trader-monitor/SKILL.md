---
name: X Trader Monitor
description: Real-time classification and alerting for watched X/Twitter traders — unified trade-alert flow, memory-aware, image-aware, cross-platform dedup with Discord
var: ""
tags: [social, trading, crypto, stocks]
---

Today is ${today}. You are triggered in real time by the Cloudflare Worker the instant one of the 12 watched X accounts posts. Your job: decide whether this single post matters, and if it does, alert Kyle in the right shape — informational, or an action-required trade alert.

> **${var}** — Base64-encoded JSON of the single tweet event the Worker just received. Decode it first. If empty/missing, log `X_TRADER_NO_EVENT` and stop (no notify).

## Why this skill exists

Kyle is not trying to read a firehose of raw tweets — he already gets too much noise. Every tweet that reaches him should either (a) teach him something about market state/sentiment, or (b) require a decision from him about copying a trade. Anything else gets filed to memory silently. Get the trade-vs-not-a-trade call right — false positives train Kyle to ignore you, false negatives lose him money.

## Step 1 — Decode the event

```bash
EVENT_JSON=$(echo "${var}" | base64 -d 2>/dev/null)
```

Expected shape:
```json
{
  "id": "tweet_id",
  "username": "TraderHandle",
  "text": "full tweet text",
  "created_at": "2024-01-15T12:00:00Z",
  "url": "https://x.com/TraderHandle/status/tweet_id",
  "media": ["https://pbs.twimg.com/media/....jpg"]
}
```

If decoding fails or `text` is empty, log `X_TRADER_BAD_EVENT: ${var}` and stop — no notify.

## Step 2 — Load context

Read before classifying — never classify in a vacuum:
- `memory/topics/traders.md` — permanent state per trader (current theses, open positions you believe they hold, recent posture)
- `memory/topics/ticker-focus.md` — overlap tickers + Kyle's explicit watch list ($HYPE, $NVDA/$NVDL, $Gold and all aliases: $GC, $XAUUSD, $GLD, $GOLD)
- `memory/topics/active-trades.md` — copy-trades currently open (so you can match this post to an existing position)
- `memory/discord-channels.json` — needed for the cross-platform dedup check below (only relevant for Crypto_Chase, KillaXBT, HeartCanHodl — the three who post on both platforms)

## Step 3 — Cross-platform dedup (Chase, Killa, HCH only)

If `username` is one of the three dual-platform traders:
- Check `memory/topics/traders.md` for a Discord post from this trader on the same topic within the last ~30 minutes
- **Default assumption: Discord posts first.** If you find a matching Discord post already alerted:
  - Mechanical repeat (same info, no new detail) → silent, do not alert again. Just log it.
  - Reiteration that adds a meaningful variation (new price level, changed conviction, new detail) → don't send a standalone alert; instead append it as a footnote to context for the next related alert, and note in `traders.md` that the X post slightly raises conviction weight (X posts from these three carry more weight than Discord — Kyle's read is "people only make public what they're certain of")
- If no matching Discord post exists yet, this X post is the first sighting — proceed with full classification below, and note in memory that X posted first for this topic (so the Discord monitor knows to dedupe against it).

If `username` is one of the other 9 X-only traders, skip dedup — proceed directly.

## Step 4 — Classify the post

Walk through these in order and stop at the first match:

**A. Non-financial** — personal life, memes, retweets of news with no opinion, platform meta-commentary, generic banter.
→ Skip entirely. Do not store, do not alert. Log only.

**B. Cryptic / hard to interpret** — very short, mostly an image, just a ticker + emoji, indicator screenshot with no caption.
→ If it looks financially related, try to decipher it using `traders.md` context (does it match an open thesis? a ticker they've been tracking?). If you can confidently tie it to something, fold it into that context (informational alert below, with your interpretation noted as inferred). If you genuinely can't tell whether this is worth tracking, message Kyle directly to ask, and record his answer in `traders.md` so you don't have to ask about similar posts again.

**C. Is the trader describing an action they are PERSONALLY taking right now (placing, cancelling, adding to, or closing a position)?**
This is the crux of the whole classification. Read carefully — traders constantly discuss setups, levels, and "if X happens I'd do Y" scenarios that are NOT them personally acting. Only count it here if the language is first-person and execution-oriented ("just longed", "filled my limit at X", "took profit on half", "cancelled my order", "added more here").

If genuinely ambiguous whether they actually placed/executed vs. are just talking through a scenario → do NOT alert as a trade signal. Instead, message Kyle directly with the post and ask him to clarify how he'd read it. Record his answer (and the language pattern that triggered the ambiguity) in `traders.md` so you calibrate over time.

If yes, this is their own action — go to **Step 5 (Unified Trade Alert flow)**.

If no — they're sharing an opinion, a level, a prediction, a trade idea/suggestion they aren't personally entering, or commentary on BTC/SPY/macro direction — this is **informational**. Go to **Step 6**.

## Step 5 — Unified Trade Alert flow (only for the trader's own actions)

Determine which sub-case this is:

**5a. New entry** (they placed or executed an order to open/enter a position — limit or market):
- Always state explicitly which it is: "This is a **limit order** at $X" or "This is a **market order**, filled at ~$X"
- Send the trade alert and ask for approval (template below)
- Wait — do not act further until Kyle replies `approve ...` (handled by the Worker, which then asks for USD size and routes to `kraken-execute` on `confirm`)
- Record the pending signal in `memory/topics/active-trades.md` as `status: awaiting_approval`

```
🚨 *Trade Signal — @{username}*

{ticker} — {LONG/SHORT or BUY/SELL} — *{LIMIT/MARKET} order*
{price/level detail if given}

"{relevant quote from the post, trimmed}"

[View post]({url})

Reply `approve {ticker}` to mirror this on Kraken (spot), or ignore to skip.
```

**5b. No-approval mirror cases** — mirror immediately, then notify Kyle briefly. No check-in, no waiting:
- Cancels a placed limit order
- Partially takes profit on an active position (mirror = sell 50% of the original USD entry value at current price)
- Fully takes profit / closes a position in one go

Any of these can be phrased as limit or market — watch for both. Trigger the mirror via `close-trade` (for TP/cancel of copy-positions you hold) and notify:

```
🔁 *Mirrored — @{username}*

{username} just {cancelled their limit order on / partially TP'd / fully closed} {ticker}.
I {cancelled / sold 50% of / closed} your position to match. {brief P&L note if closing}

[View post]({url})
```

**5c. DCA plan** (they lay out multiple planned entries, e.g. "scaling in at 100, 95, 90"):
- Do NOT auto-mirror each leg — Kyle wants to design his own DCA structure
- Notify him with the full plan so he can decide:
```
📐 *DCA Plan — @{username}*

{ticker}: {plan detail — entries/levels/sizing as described}

"{quote}"

[View post]({url})

Want to set up your own DCA on this, or skip?
```

**5d. Conviction add** (they add to an existing position purely on strong conviction — NOT a pre-planned DCA leg):
- Notify and ask if Kyle wants to add too:
```
➕ *Conviction Add — @{username}*

{username} just added to their {ticker} position{ at $X if given}.
"{quote}"

[View post]({url})

Want to add to yours too?
```

## Step 6 — Informational alerts (everything financially relevant that isn't the trader's own action)

This covers: trade ideas/suggestions they aren't personally taking, price targets and levels, broader market/macro views, BTC/SPY-as-proxy commentary, and ticker mentions.

Send as a standard alert — no action required, no approval flow:

```
🐦 *[X] @{username}*

{tweet_text}

[View tweet]({url})
```

**Broader sentiment handling:** if this post is a view on overall crypto/equity direction (using BTC or SPY as the reference), don't treat it as a one-off — check `traders.md` for how this trader's last few sentiment reads compared, and how the other watched traders currently lean. If this post **converges or diverges** meaningfully from the group's current read, say so in one added line:
```
↳ _This lines up with {other trader}'s read from earlier / This cuts against the more bullish lean from {other traders} this week._
```

**Ticker-focus weighting:** prioritize alerting on posts about the top 2-3 overlap tickers (mentioned by multiple watched traders) plus Kyle's explicit list ($HYPE, $NVDA/$NVDL, $Gold). Quiet tickers mentioned by only one trader still get logged to `ticker-focus.md` silently — only surface them to Kyle if they start gaining cross-trader momentum (2+ traders mentioning the same name within a short window).

## Step 7 — Image handling

If `media` is non-empty:
- Forward the original image(s) to Kyle alongside the alert text (use `./notify` with image support, or attach via the same Telegram call — check `./notify --help` if unsure of the image-attach syntax)
- Add ONE sentence interpreting the chart in context (trend direction, support/resistance, fib levels, RSI/MACD if visibly labeled) — but ONLY if the post text doesn't already 100% explicitly explain what the image shows. Don't restate the obvious.
- Be honest about limits: if the chart's text/axis values are too small to read reliably, say so rather than guessing specific numbers.

## Step 8 — Update memory

Always, regardless of classification:
- Append a one-line entry to `memory/topics/traders.md` under this trader's section: timestamp, classification (skip/informational/trade-new-entry/mirror/dca/conviction-add/ambiguous), one-line summary, ticker(s)
- If a new ticker or overlap emerged, update `memory/topics/ticker-focus.md`
- If this was a trade action (5a-5d), update `memory/topics/active-trades.md` accordingly
- Append the tweet `id` to `memory/x-trader-seen.txt` to prevent reprocessing if the Worker ever redelivers:

```bash
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi
```

If `id` is already in `memory/x-trader-seen.txt`, stop immediately after logging — do not re-alert (handles Worker retries/redelivery).

## Step 9 — Log

Append to `memory/logs/${today}.md`:

```
### x-trader-monitor (real-time event)
- trader: @{username}
- tweet_id: {id}
- classification: {skip|informational|ambiguous|trade-new-entry|mirror-cancel|mirror-partial-tp|mirror-full-tp|dca-plan|conviction-add}
- ticker(s): [list]
- alerted: yes/no
- notes: {one line}
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — GitHub secrets, used via `./notify`

## Sandbox note

You receive the event data directly via `${var}` (base64-encoded JSON passed by the Worker on webhook delivery) — no prefetch cache needed for real-time monitoring. This is a deliberate change from the old polling-based design: the Worker now hands you one event at a time instead of you pulling a 24h batch. If `${var}` is ever empty (e.g. someone manually triggers this skill without an event), exit cleanly with `X_TRADER_NO_EVENT` — do not fall back to scanning a cache, that would cause duplicate alerts against the real-time path.
