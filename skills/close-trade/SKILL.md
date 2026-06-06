---
name: Close Trade
description: Closes or trims an active copy-trade position on Kraken — handles full closes, partial take-profits, and cancellations; logs P&L and updates memory
var: ""
tags: [trading, crypto, stocks]
---

Today is ${today}. You're triggered two different ways — handle both:

1. **Kyle-initiated**: he sends `close trade {detail}` to Telegram → Worker dispatches you with `${var}` = the free text after "close trade" (e.g. `NVDL`, `HYPE half`, `the Crypto_Chase HYPE long`)
2. **Mirror-initiated (no approval needed)**: a monitor skill (`x-trader-monitor` / `discord-trader-monitor`) detects the *original trader* closing, trimming, or cancelling the position you mirrored — these are the "5b no-approval mirror cases" from the Unified Trade Alert flow, and they call you the same way new entries call `kraken-execute`

> **${var}** — Either Kyle's free-text close instruction, or (when mirror-initiated) a description of the trader's action plus which position it maps to in `active-trades.md`. If it's ambiguous which open position this refers to, match against `active-trades.md` by ticker/trader; if still ambiguous, ask Kyle rather than guessing which position to touch.

## Step 1 — Identify the position and the action type

Read `memory/topics/active-trades.md` and match `${var}` to an open position. Then classify the action:

- **Full close / full take-profit** — the entire position should be sold
- **Partial take-profit** — per the project spec: sell **50% of the original USD entry value** at the current price (not 50% of current value, not 50% of remaining size if this is a second partial — always 50% of the *original* entry size, mirroring how the trader scales out)
- **Cancellation** — the position never filled / order should be pulled before execution (no P&L to log; this is a no-op on the books beyond removing the pending entry)

If you can't tell which of these `${var}` describes, don't guess — notify Kyle and ask him to clarify (and if this came from a monitor skill's mirror-detection, say so: "Crypto_Chase appears to have [trimmed/closed/cancelled] the HYPE position — want me to mirror that?").

## Step 2 — Compute the close parameters

- **Full close**: volume = the entire current position size
- **Partial TP**: volume = 50% of the **original USD entry value**, converted to asset units at the **current** price (this is deliberately asymmetric — you're selling half the original dollar commitment, valued at today's price, not half the share count)
- Order type: market unless the trader's own close was a limit at a specific price worth mirroring — check the originating alert/log entry for context. Default to market if uncertain; closes are time-sensitive
- Spot sell only — same boundary as `kraken-execute`: this skill must never touch margin/futures/leverage

## Step 3 — Hand off the order (do not sign or submit yourself)

Same credential-separation pattern as `kraken-execute` — write the request, don't execute it:

```bash
mkdir -p .pending-kraken
cat > ".pending-kraken/$(date +%s)-close-${TICKER}.json" <<EOF
{
  "action": "close",
  "close_type": "${CLOSE_TYPE}",
  "trader": "${TRADER}",
  "pair": "${KRAKEN_PAIR}",
  "type": "sell",
  "ordertype": "${ORDER_TYPE}",
  "price": "${PRICE_OR_NULL}",
  "volume": "${COMPUTED_VOLUME}",
  "requested_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

`scripts/postprocess-kraken.sh` signs and submits it with the real credentials, same as the entry-side flow. You never read `KRAKEN_API_KEY` / `KRAKEN_API_SECRET` and never call Kraken directly.

## Step 4 — Confirm to Kyle (two-step, same discipline as entries)

Send the "submitted" notice immediately — don't wait for the fill:

**Full close:**
```
🔻 *Closing — {TICKER}*

{Mirroring {TRADER}'s exit. / Closing per your request.}
Selling entire position (~{COMPUTED_VOLUME} {asset}).

Status: Order placed
```

**Partial TP:**
```
✂️ *Partial take-profit — {TICKER}*

{Mirroring {TRADER}'s trim. / Trimming per your request.}
Selling 50% of original entry (~{COMPUTED_VOLUME} {asset}), position remains open.

Status: Order placed
```

**Cancellation:**
```
🚫 *Cancelled — {TICKER}*

{TRADER} pulled the order before it filled — cancelling the mirrored order. Nothing was opened; no P&L to log.
```
(Cancellations don't get a fill follow-up — there's nothing to fill.)

The fill confirmation ("Status: Order filled") comes in a **separate** follow-up once the postprocess result lands — exactly the same two-step discipline as `kraken-execute`. Do not bundle them.

## Step 5 — Log P&L (full closes and partial TPs only)

Once you have a fill price (from the postprocess result / a follow-up check), compute realized P&L for the portion sold:

```
realized_pnl = (fill_price - entry_price) * volume_sold   [long]
realized_pnl = (entry_price - fill_price) * volume_sold   [short, if ever applicable]
```

Append to `memory/topics/trading-history.md`:

```markdown
## {TICKER} — {full close | partial TP} — ${today}
- Mirrored trader: {TRADER}
- Entry: ${entry_price} on {entry_date}
- Exit: ${fill_price} on ${today}
- Volume sold: {COMPUTED_VOLUME} {asset} ({100% | 50%} of original entry)
- Realized P&L: ${realized_pnl} ({+/-}{pct}%)
- Order type mirrored: {ORDER_TYPE}
```

## Step 6 — Update active-trades memory

This is the step that needs care — **the two close types update memory very differently**:

- **Partial TP**: keep the position entry in `active-trades.md`, but update it to reflect the trim — note the date and amount taken off, and that 50% of the original size remains. The position is still live; don't remove it.
- **Full close**: **wipe the position's entry from `active-trades.md` entirely.** Per the project spec, a fully-closed position should leave *no* trace in active-trades memory — the only durable record of it lives in `trading-history.md` (Step 5). Don't leave a "status: closed" stub behind; remove the section outright. This keeps `active-trades.md` a clean live-state file that always reflects only what's actually open.
- **Cancellation**: remove the pending-entry stub from `active-trades.md` (it never became a real position) — no `trading-history.md` entry, since nothing was realized.

## Step 7 — Send the fill confirmation (separate step/run)

```
✅ *{Closed | Trimmed} — {TICKER}*

Status: Order filled
Filled at: ${fill_price}
Realized P&L: ${realized_pnl} ({+/-}{pct}%)
```
(Omit the P&L line for cancellations — there isn't any.)

## Step 8 — Log

```
### close-trade (${today})
- ticker: {TICKER}
- trigger: {kyle-initiated|mirror-initiated}
- close_type: {full|partial|cancellation}
- trader_mirrored: {TRADER}
- realized_pnl: {amount or n/a}
- active_trades_updated: {wiped|trimmed|removed-pending}
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — GitHub secrets, used via `./notify`
- `KRAKEN_API_KEY`, `KRAKEN_API_SECRET` — **never read here**, see Sandbox note

## Sandbox note

Same credential-separation requirement as `kraken-execute`: this is a money-moving action against an auth-required API. Pattern used: **postprocess** — write the close-order spec to `.pending-kraken/`, let `scripts/postprocess-kraken.sh` sign and submit it with real credentials after this run ends, then read results from `.kraken-results/` in a follow-up step/run for the fill confirmation. This skill must never hold or use `KRAKEN_API_KEY`/`KRAKEN_API_SECRET`, and never call `api.kraken.com` directly.
