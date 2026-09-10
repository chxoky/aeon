# TradingView Alerts → Kraken / Alpaca Execution

TradingView never touches a brokerage. An alert fires a webhook into this Worker;
the Worker decides, sizes, routes and executes. **TradingView is the eyes, the
Worker is the hands.**

Spec background and the API-surface map: `~/Claude/Projects/Telegram Bot Discord/TradingView/ARCHITECTURE.md`

---

## Why two venues

| | Crypto | US equities / ETFs |
|---|---|---|
| Venue | **Kraken** | **Alpaca** |
| Why | Existing account + keys; `postprocess-kraken.sh` already signs this way | Kraken's equities product is **UI-only — no order API** and has **no extended-hours trading** at all (orders outside 09:30–16:00 ET queue to the next open) |
| Sessions | 24/7, no session logic | Full session router: open / pre / post / closed |

Alpaca is the broker-dealer behind Kraken's own equities product, so this is the
same execution venue Kraken would have used — just reachable programmatically.

---

## Safety model

The approval boundary mirrors what `skills/kraken-execute/SKILL.md` and
`skills/close-trade/SKILL.md` already document:

| Action | Default | Rationale |
|---|---|---|
| `trim`, `close`, `cancel` | **auto-executes** | `close-trade` already calls this the *"mirror-initiated, no approval needed"* path |
| `open`, `add` | **asks first** in Telegram | you approve every new entry |

Setting `"confirm": false` on an entry rule moves the approval **upstream**: you
are approving that entry when you *arm the rule*, not when it fires. That is a real
change to the boundary you set, so it is opt-in per rule and never implicit.

Four more guards, all independent:

1. **`RuleState` Durable Object** — the one-shot / cooldown / max-fires claim.
   KV cannot do this (no compare-and-set, eventually consistent) and TradingView
   webhook delivery is explicitly at-least-once, so a double-sell is a real
   failure mode, not a theoretical one.
2. **`client_order_id`** on every Alpaca order — Alpaca rejects duplicates outright.
3. **`max_slippage_pct`** — refuses to trade into a spread wider than you allow.
4. **Paper by default** — Alpaca goes to paper trading unless `ALPACA_LIVE` is
   *exactly* the string `true`.

Credential boundary: `src/tv/kraken.js` and `src/tv/alpaca.js` are the only places
brokerage keys are touched. They are deterministic code, never a model prompt — the
same invariant `postprocess-kraken.sh` enforces, drawn at the module rather than
the process.

---

## Setup

### 1. Secrets

```bash
cd ~/aeon/worker
wrangler secret put TV_WEBHOOK_SECRET        # long random string you invent
wrangler secret put KRAKEN_API_KEY
wrangler secret put KRAKEN_API_SECRET
wrangler secret put ALPACA_API_KEY_ID
wrangler secret put ALPACA_API_SECRET_KEY
```

Leave `ALPACA_LIVE` unset while testing — Alpaca stays on paper. To go live later,
add `ALPACA_LIVE = "true"` under `[vars]` in `wrangler.toml`.

Kraken key permissions: **Create & modify orders** and **Query funds**. Do *not*
enable withdrawal on this key.

### 2. Deploy

```bash
cd ~/aeon/worker && wrangler deploy
```

The first deploy creates the `RuleState` Durable Object via the `v1-rule-state`
migration. Your existing `/telegram`, `/twitter` and Discord cron paths are untouched.

### 3. Create the TradingView alert

Set the alert condition however you like on any chart. Then:

- **Notifications → Webhook URL**: `https://trading-bot.chxoky.workers.dev/tv-alert`
- **Message**: paste the JSON below (TradingView sends the message body verbatim,
  substituting `{{...}}` placeholders)
- **Trigger**: prefer *Once Per Bar Close* over *Once Per Bar* — the latter fires
  on every tick that satisfies the condition

Requires a TradingView **Plus plan or higher** with 2FA enabled.

---

## Alert payload

```json
{
  "secret": "your-TV_WEBHOOK_SECRET",
  "id": "btc-loses-92k-trim-bitx",
  "action": "trim",
  "symbol": "BITX",
  "size": { "pct": 40 },
  "urgency": "fast",
  "when_closed": "queue",
  "max_slippage_pct": 1.5,
  "one_shot": true,
  "cooldown_sec": 300,
  "note": "BTC lost 92k — cutting leveraged BTC ETF exposure",
  "tv": { "ticker": "{{ticker}}", "price": "{{close}}", "time": "{{timenow}}" }
}
```

### Fields

| Field | Required | Meaning |
|---|---|---|
| `secret` | ✅ | must equal `TV_WEBHOOK_SECRET` |
| `id` | ✅ | **stable** rule identifier, `[A-Za-z0-9_.:-]`, ≤64 chars. Keyed to the Durable Object — reusing an id shares its fire state |
| `action` | ✅ | `open` · `add` · `trim` · `close` · `cancel` |
| `symbol` | ✅ | ticker to **trade** — not necessarily the alert's chart symbol |
| `venue` | | `kraken` · `alpaca`. Omit to resolve from `src/tv/symbols.js` |
| `pair` | | override the Kraken pair |
| `size` | for all but `close`/`cancel` | **exactly one** of `{"pct":40}` (of position) · `{"usd":500}` · `{"qty":1.5}` |
| `urgency` | | `fast` (default) → market when open, limit-at-touch otherwise · `patient` → requires `limit_price` |
| `limit_price` | with `patient` | explicit limit |
| `when_closed` | | `queue` (default, rests until open) · `abort` |
| `max_slippage_pct` | | refuse if the spread is wider than this |
| `confirm` | | override the approval default for this rule |
| `one_shot` | | `true` → fires once, then disarms until re-armed |
| `cooldown_sec` | | minimum seconds between fires (default 60) |
| `max_fires` | | lifetime cap |
| `dry_run` | | validate and report without placing anything |
| `note` | | free text, echoed into the Telegram confirmation |
| `tv` | | pass `{{ticker}}` / `{{close}}` / `{{timenow}}`; `time` also feeds idempotency |

### Order-type selection

`urgency: "fast"` resolves against the live session **at execution time**, never
at trigger time — an order correct at 15:59 is rejected at 16:01:

| Session | Crypto (Kraken) | Equities (Alpaca) |
|---|---|---|
| Regular hours | market | market |
| Pre / post | *(n/a — 24/7)* | **limit at best bid** (sell) / best ask (buy), `extended_hours=true` |
| Closed | *(n/a)* | `when_closed: queue` → limit day order resting to the open · `abort` → refuse |

---

## Examples

**Cross-asset trim** — BTC breaks down, cut the leveraged BTC ETF. Alert set on a
BTC chart; the order lands on BITX at Alpaca.

```json
{ "secret": "...", "id": "btc-92k-trim-bitx", "action": "trim",
  "symbol": "BITX", "size": { "pct": 40 }, "urgency": "fast",
  "one_shot": true, "max_slippage_pct": 2,
  "note": "BTC lost 92k", "tv": { "price": "{{close}}", "time": "{{timenow}}" } }
```

**Full exit on a crypto spot position** — 24/7, no session branch.

```json
{ "secret": "...", "id": "hype-invalidation", "action": "close",
  "symbol": "HYPE", "urgency": "fast", "one_shot": true }
```

**New entry, still asks first** — the default for `open`.

```json
{ "secret": "...", "id": "sol-reclaim-entry", "action": "open",
  "symbol": "SOL", "size": { "usd": 500 }, "urgency": "patient",
  "limit_price": 182.50, "note": "Chase's reclaim level" }
```

Telegram replies with a confirmation card; you answer `go sol-reclaim-entry` or
`deny sol-reclaim-entry`.

**Fully automated entry** — approval moved to rule-arming time.

```json
{ "secret": "...", "id": "eth-breakout-auto", "action": "open",
  "symbol": "ETH", "size": { "usd": 250 }, "confirm": false,
  "one_shot": true, "cooldown_sec": 3600 }
```

---

## Testing before real money

1. **Dry run** — add `"dry_run": true`. Kraken validates the order without placing
   it (`validate=true`); Alpaca reports what it would have sent. You get a Telegram
   card marked 🧪 either way.
2. **Paper** — leave `ALPACA_LIVE` unset. Every equity order goes to Alpaca paper
   and the Telegram card is marked 📝 PAPER.
3. **Curl it directly** — no TradingView needed:

```bash
curl -X POST https://trading-bot.chxoky.workers.dev/tv-alert \
  -H 'Content-Type: application/json' \
  -d '{"secret":"...","id":"smoke-test","action":"trim","symbol":"BITX","size":{"pct":1},"dry_run":true}'
```

4. **Unit tests** — `cd ~/aeon/worker && node test/tv-alert.test.mjs` (32 assertions;
   no network or credentials needed).

---

## Operating notes

- **Inspecting and re-arming rules** — `POST /tv-rule`:

  ```bash
  # what happened on this rule?
  curl -s -X POST https://trading-bot.chxoky.workers.dev/tv-rule \
    -H 'Content-Type: application/json' \
    -d '{"secret":"...","id":"btc-92k-trim-bitx","op":"status"}'

  # restore the fire slot on a spent one-shot
  curl -s -X POST https://trading-bot.chxoky.workers.dev/tv-rule \
    -H 'Content-Type: application/json' \
    -d '{"secret":"...","id":"btc-92k-trim-bitx","op":"rearm"}'
  ```

  `status` returns `fires`, `armed`, and the last 25 fires with their outcome and
  error detail — the fastest way to answer "did that actually fire, and what happened".
- **A rejected order does not re-arm.** Only a *transport* failure (never reached
  the venue) restores the fire slot. A venue rejection is a real outcome and is
  reported as such.
- **Nonce sharing.** The Worker and `postprocess-kraken.sh` share one Kraken nonce
  space and both use **milliseconds**. Do not change either to microseconds — the
  other one's orders would start failing with `EAPI:Invalid nonce`.
- **Adding an instrument** — edit `KRAKEN_SYMBOLS` / `ALPACA_SYMBOLS` in
  `src/tv/symbols.js`. Unknown symbols are rejected, never guessed: `BTC` and `IBM`
  are both three uppercase letters, so any shape heuristic is a coin flip with money on it.
- **Alpaca fractional shares** don't support all order types; if a fractional
  `qty` is rejected, use a whole-share `qty` or a `usd` notional during RTH.

## Verified live (2026-09-10, post-market)

End-to-end smoke test against the deployed Worker, all `dry_run`:

| Check | Result |
|---|---|
| Wrong secret | `401 unauthorized` |
| Malformed body / unknown symbol / `open` sized by pct | `400` with the specific reason |
| Duplicate `fire_id` | `skipped: duplicate_fire_id` |
| `open` without `confirm:false` | `awaiting confirmation` |
| Kraken auth + HMAC signing | reached the API, read balances → *"no XBT balance to trim"* |
| Alpaca auth | reached the API, read positions → *"no open BITX position"* |
| Session router at 17:12 ET | `DRY RUN — would buy 1.464557 BITX limit @ 17.07 (ext hours)` |

That last line is the one that matters: post-market detected, market order converted
to a limit, priced at the ask, correctly sized. An earlier version of `marketStatus`
classified every post-market moment as "closed" and silently dropped `extended_hours` —
see the comment in `src/tv/alpaca.js`.

## Files

| File | Role |
|---|---|
| `src/tv/index.js` | Handler: auth, validation, claim, approval gate, session router |
| `src/tv/kraken.js` | Kraken adapter — HMAC-SHA512 signing, AddOrder, Balance, cancel |
| `src/tv/alpaca.js` | Alpaca adapter — orders, positions, clock, quotes, close-position |
| `src/tv/rules.js` | `RuleState` Durable Object — the one-shot / cooldown claim |
| `src/tv/symbols.js` | Symbol → venue resolution (strict, no heuristics) |
| `test/tv-alert.test.mjs` | 53 assertions over validation, the guard, and session boundaries |
