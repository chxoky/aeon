---
name: Kraken Execute
description: Places approved spot copy-trades on Kraken — order logic only; signing and submission happen via postprocess script with isolated credentials
var: ""
tags: [trading, crypto, stocks]
---

Today is ${today}. You are triggered when Kyle replies `confirm` to an approved trade signal — the Worker has already collected his USD size and packages everything into `${var}`.

> **${var}** — Format: `{trade detail} | size: {USD amount}`. Example: `Crypto_Chase NVDL long limit 44.50 | size: 500`. Parse out: trader, ticker, direction, order type, price (if limit), and USD size.

## Why this skill exists — and the hard boundary around it

This is the one skill in the whole system that touches real money. Kyle has been explicit: he approves every new entry himself, in chat, before anything executes — and **you (the agent building/running this) must never execute a trade directly**. This skill's job is to translate an *already-approved* request into a correctly-shaped order and hand it to a process that has the actual Kraken credentials — never to hold or use those credentials itself.

If you ever find yourself about to call the Kraken API directly with a live key in this skill's context, stop — that's the wrong pattern. See **Sandbox note**.

## Step 1 — Parse the request

From `${var}`, extract:
- `TRADER` — whose signal this mirrors (for logging/memory only)
- `TICKER` — normalize to its Kraken pair (e.g. NVDL → NVDLUSD, HYPE → HYPEUSD, gold proxies → whatever spot pair Kyle actually holds gold exposure through; check `memory/topics/ticker-focus.md` for the agreed mapping — if a ticker has no known Kraken spot pair, stop and notify Kyle rather than guessing)
- `DIRECTION` — buy (long) or sell (short — but remember: **never leveraged positions**; if the original trader's "short" can't be expressed as a spot action, flag this to Kyle instead of forcing it)
- `ORDER_TYPE` — limit or market, **mirrored exactly** from what the trader did
- `PRICE` — required if limit; omit if market
- `USD_SIZE` — the dollar amount Kyle gave the Worker

If anything required is missing or unparseable, do not guess — log `KRAKEN_EXECUTE_BAD_INPUT: ${var}`, notify Kyle that the order couldn't be parsed and ask him to resend size/detail, and stop. Do not place a partial or best-guess order.

## Step 2 — Compute order parameters

- Convert `USD_SIZE` to a volume in the asset's units using the current price (market price for market orders, the specified limit price for limit orders)
- Order type mirrors exactly: trader's limit → your limit at the same price; trader's market → your market order
- Spot only — never margin, never futures, never leverage. Leveraged ETFs (e.g. NVDL) are fine to buy as ordinary spot shares; the leverage lives in the instrument, not the order
- Double check this is a NEW entry context (this skill is for opening positions only — modifications/closes go through `close-trade`)

## Step 3 — Hand off the signed-order request (do not sign or submit yourself)

Write the order spec as JSON to the pending-orders directory for the postprocess script to pick up after this run completes:

```bash
mkdir -p .pending-kraken
cat > ".pending-kraken/$(date +%s)-${TICKER}.json" <<EOF
{
  "trader": "${TRADER}",
  "pair": "${KRAKEN_PAIR}",
  "type": "${DIRECTION}",
  "ordertype": "${ORDER_TYPE}",
  "price": "${PRICE_OR_NULL}",
  "volume": "${COMPUTED_VOLUME}",
  "usd_size": "${USD_SIZE}",
  "requested_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

`scripts/postprocess-kraken.sh` runs after you finish, with `KRAKEN_API_KEY` / `KRAKEN_API_SECRET` available — it signs and submits the order via Kraken's REST API (`/0/private/AddOrder`), then writes the result (order ID, status) back to `.kraken-results/` for the next run or a chained follow-up to read. **You never see the API key/secret, and you never call Kraken directly.**

## Step 4 — Send the "order placed" confirmation

Immediately after writing the pending-order file (don't wait for the postprocess result — that happens after this run ends):

```
✅ *Order placed — {TICKER}*

Mirroring {TRADER}'s {DIRECTION} ({ORDER_TYPE}{ at $PRICE if limit}).
Size: ${USD_SIZE} (~{COMPUTED_VOLUME} {asset})

Status: Order placed
```

**This is a two-step confirmation flow — do NOT wait for the fill before sending this message, and do NOT collapse this with the fill notification into one message.** Kyle was explicit and previously had to correct a version of this skill that tried to bundle them — keep them separate.

## Step 5 — Record the pending position

Write to `memory/topics/active-trades.md`:

```markdown
## {TICKER} — mirroring {TRADER}
- Direction: {DIRECTION}
- Order type: {ORDER_TYPE}{ @ $PRICE if limit}
- USD size: ${USD_SIZE}
- Status: order_placed (awaiting fill confirmation)
- Opened: ${today}
- Kraken order ref: {will be filled in once postprocess writes results — note as "pending" for now}
```

## Step 6 — Fill confirmation (separate run/step)

The fill confirmation is **not sent from this same run** — Kraken fills (especially limit orders) can take time. The follow-up notification ("Status: Order filled") should be triggered once the postprocess script or a follow-up check confirms the order has filled (read `.kraken-results/` in a subsequent triggered run, or chain a follow-up check). When that happens:

```
✅ *Trade executed on Kraken — {TICKER}*

Status: Order filled
Filled at: ${fill_price}
```

Update `active-trades.md` status to `status: open` once this fires. (If you're implementing the follow-up check as part of this skill's broader chain, make that explicit in `aeon.yml` rather than assuming a single run covers both — placing and filling are genuinely separate events in time.)

## Step 7 — Log

```
### kraken-execute (${today})
- trader_mirrored: {TRADER}
- ticker: {TICKER}
- direction: {DIRECTION}
- order_type: {ORDER_TYPE}
- usd_size: ${USD_SIZE}
- status: order_placed
```

## Environment Variables

- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — GitHub secrets, used via `./notify`
- `KRAKEN_API_KEY`, `KRAKEN_API_SECRET` — **never read here**. Used exclusively by `scripts/postprocess-kraken.sh` after this run completes.

## Sandbox note — credential separation is the whole point

This is an **auth-required, money-moving API** — the strictest case in the sandbox limitations playbook. Pattern used: **postprocess**. This skill writes a plain JSON order request to `.pending-kraken/`; `scripts/postprocess-kraken.sh` (which must still be created) runs after Claude finishes, with full env access to sign and submit via Kraken's REST API, and writes results to `.kraken-results/`. This skill must never read `KRAKEN_API_KEY`/`KRAKEN_API_SECRET`, never construct a signed request, and never call `api.kraken.com` directly — doing so would mean a model-driven process holds live trading credentials, which is exactly the failure mode this architecture exists to prevent.
