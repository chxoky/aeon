# Trader State

> Rebuilt by `trader-bootstrap` on 2026-06-08 (force re-run, 3-day lookback, 2026-06-05 → 2026-06-08).
> X cache was empty at bootstrap (`TRADER_BOOTSTRAP_X_EMPTY`) — the 9 X-only accounts
> below have no recorded state yet and will be populated by `x-trader-monitor`.
> The 3 Discord-tracked traders have full state from the Discord cache (326 messages this run; count fluctuates run-to-run as the prefetch re-fetches, but the signal-bearing posts are stable).
> Re-verified intact line-by-line against the raw cache on force re-run #6 (2026-06-08); no state changes. All 326 Discord cache IDs already marked seen (Step 7 idempotent); X cache still empty.

## Crypto_Chase
- Platforms: X + Discord (primary: 1336082716063694962; Q&A: 1343971265962049597, 1247927786681794601)
- Current open positions (as of bootstrap):
  - GOLD — long (spot) — still open as of 2026-06-07, stop not yet hit; expects it may stop and "sweep into the box". Uses SPY for spot, ES futures for active trades.
  - HYPE — FLAT. Layered long was stopped out -1.5R on 2026-06-05. Re-bids set then fully cancelled 2026-06-06 ("All other orders on HYPE cancelled"). Now eyeing low-50s for possible re-entry but leaning that more downside is likely. Said a stop-out here would be "my last HYPE trade for a long time".
  - NVDA — FLAT. Cut 2026-06-05 at 208.7 (H4 close below key HTF level) for very minor profit (entry 210, half TP at 216).
- Recent thesis/posture: Turned cautious/bearish on crypto after the HYPE stop — notes BTC broke below the weekly 200 EMA (last time preceded a longer bear market), gut says more downside + consolidation. Frames the HYPE action as anomalous (HTF levels gave zero reaction). Thinks the AI bubble may have popped; rotating to trad: likes INTC (low 90s–mid 80s), Micron/MU (~790–820), silver (~53 spot), S&P/SPY bid on a strong multi-week pullback. On BTC: doesn't see 65.6 breaking unless Saylor sold heavily; until a strong close above 63, doesn't see much more upside.
- Conviction notes: Process-driven, level/confluence trader (FVGs, weekly SR, fib, 618). Verbose, transparent about R-risk and invalidation. Will defend a thesis through drawdown but cuts on clean HTF invalidation. Discord now Rainbet-sponsored; some posts are sponsor/engagement asks (ignore for signal).
- Last seen: 2026-06-08T00:55Z (overnight chop commentary; focusing on charts from the weekly-plans stream, warned he'll be less responsive to chart requests this week)

## KillaXBT
- Platforms: X + Discord (primary: 1411492188315193416)
- Current open positions (as of bootstrap):
  - BTC — long (low-leverage swing) — carried forward from prior bootstrap (built 2026-06-04, ~75% exposed, intends to hold "a very long time"). NOTE: that entry detail is outside this 3-day window; the only in-window KillaXBT post is a 2026-06-06 "little update regarding my thoughts on BTC" pointing to a stream (content not cached). No explicit position change captured this window.
- Recent thesis/posture: Last cached view (prior bootstrap): bottom is "close"; wants a multi-week range above 60K before any possible capitulation candle below the lows; local-reclaim targets ~68.2K, ideally 69.3K–70K. Sentiment-contrarian, patient, manual invalidation. Verify against the 2026-06-06 stream update once available.
- Conviction notes: Low-leverage, long-horizon swing style; explicitly warns impatient followers off. Very terse — posts often point to a stream rather than stating the change inline.
- Last seen: 2026-06-06T17:29Z
- **PENDING (carried):** 2026-06-08T08:00 "BTC test" flagged AMBIGUOUS by real-time monitor — too cryptic to classify; awaiting Kyle's calibration on intent (test/signal/typo). Not present in this bootstrap cache; preserved so the open question isn't lost.

## HeartCanHodl
- Platforms: X + Discord (free/public: 1472153627324842057; primary/most-important: 1279738718680256553; premium chat: 1023638573313966212)
- Current open positions (as of bootstrap) — runs a HEDGED book:
  - BTC / ETH / SOL — spot longs, hedged 2x short around 63–64k. Net cautious; ETH lows called "great MTF/HTF price".
  - ZEC — short (large), built/added repeatedly (06-06 → 06-07), rebalanced ~405 on 06-07. Expects further downside ("coming for all those mechanical bounce chasers", their stops at BE).
  - VVV — short, 3x, added 2% 06-06, +2% 06-07, rebalanced ~15.8 on 06-07.
  - LAB — short, ~1x, half of the book; re-added 2% 1x at $13 on 06-07. Part of the bearish-alt basket.
  - HYPE — short, added 2% at 2x on 06-07 (from a separate account).
  - WLD — short (part of the short basket).
- Recent thesis/posture: Defensive/hedged. 63k is the key line — above = support, below = "much riskier territory". Risk triggers firing frequently. Prefers not to close green shorts/hedges overnight or in the Asia session. Watching what Saylor actually did for next market direction. Called one name "a free short", ideally 320 or 190, upside capped (won't revisit ATH).
- Conviction notes: Very terse shorthand — "fc {ticker} {tf}" = forecast/chart, "sc" = chart, "pf" = portfolio %, "BE" = breakeven. Posts liquidation feeds and X reposts in the public channel (low signal). Real position changes come as explicit "add/tp/enter/short {ticker} {%}" lines, mostly in 1279738718680256553 and premium 1023638573313966212. Warns against adding to already-green positions (worsens cumulative entry, hurts psychology).
- Last seen: 2026-06-07T19:47Z

---

## X-only watched accounts (no data at bootstrap — X cache empty)
State to be populated by `x-trader-monitor` once X history flows.
- Bitcoin_Astro — Platforms: X. No state yet.
- abetrade — Platforms: X. No state yet.
- trading_axe — Platforms: X. No state yet.
- t_in_crypto — Platforms: X. No state yet.
- ryzzqq — Platforms: X. No state yet.
- swarmister — Platforms: X. No state yet.
- bull_genius — Platforms: X. No state yet.
- Stoiiic — Platforms: X. No state yet.
- Wild_Randomness — Platforms: X. No state yet.

BOOTSTRAP_COMPLETE: 2026-06-08
