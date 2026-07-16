# Memory Index
*Last consolidated: 2026-06-08*

## About This Project
Autonomous trading-signal agent running on GitHub Actions via Claude Code. Monitors X (twitterapi.io webhook) and Discord (Cloudflare Worker cron) for tracked trader activity, routes alerts to Telegram/Discord.

## Current Goals
- Monitor 12 trader accounts (3 Discord-cross-tracked + 9 X-only) for position changes in real time
- Route high-signal alerts to Kyle via Telegram (primary)
- Maintain accurate `memory/topics/traders.md` trader state across sessions

## Live Stack (as of 2026-06-08)
- **X inbound:** twitterapi.io webhook → Cloudflare Worker `/twitter` → `x-trader-monitor` (~20s latency)
- **Discord inbound:** Worker cron every 1 min → `discord-trader-monitor`
- **Telegram inbound:** Worker `/telegram` → instant routing (concierge, brief, etc.)
- **Telegram outbound:** `./notify` in all skills (token-strip fix applied)
- **GitHub Actions cron:** monitors have `enabled: false` in aeon.yml — intentionally webhook/Worker-triggered only, no cron fallback (corrected 2026-07-13; the `*/15` fallback line was stale)

## Tracked Tokens
| Token | CoinGecko ID | Alert Threshold |
|-------|-------------|-----------------|
| BTC   | bitcoin     | 10%             |
| ETH   | ethereum    | 10%             |
| SOL   | solana      | 10%             |
| HYPE  | hyperliquid | 10%             |

## Active Topics
- [Trader State](topics/traders.md) — All 12 traders, current positions, last seen timestamps. Fully rebuilt by `trader-bootstrap` 2026-07-14 (force, 7-day lookback Jul 7–13; 248 tweets + 1,133 Discord msgs, both platforms populated). No stale sections.
- [Ticker Focus](topics/ticker-focus.md) — Overlap/contested tickers across traders, Kyle's explicit watch list, X-sourced equities. Rebuilt 2026-07-14.
- [Market Context](topics/market-context.md) — Latest regime snapshot, BTC price, F&G index.
- [Skill of the Day](topics/skill-of-the-day.md) — Most recent SOTD output.

## Current Trader Posture (summary, 2026-07-14, trader-bootstrap force 7-day re-run)
> BTC range-bound low-to-mid 60Ks (−53% off cycle high); Jul 13 (Mon) −3% to a lower high ~64.7K. Structural bulls vs tactical bears; consensus = choppy bear grind, HTF bottom "close." CPI Wed Jul 15 = week's vol event. Equities: semis/AI corrected then NVDA + memory (MU/SNDK) bounced; SPX pressing new ATHs.
- **KillaXBT:** HTF-bull BTC maxi. Holds **2x BTC swing long @62.6K + spot** (majority of port); adds spot at 54K, buys IBIT in Aug. Expects 1–2mo chop, a capitulation wick to 49–56K marks the bottom. SOL "never sees ATH again." Conditional LTF short into the 14th pivot — likely not taken.
- **HeartCanHodl:** Firmly bearish. **Short basket BTC/ETH/SOL/HYPE/ZEC** (re-entered ½ Jul 10, added BTC Jul 13) + winning **SPCX short** (ATL Jul 13). Closed LAB short for big profit. BTC can't hold 62.8K. SOL weakest major.
- **Crypto_Chase:** FLAT crypto after banking memory-stock flush longs (SNDK/MU TP'd in profit). Watching SPX/ES long for new ATHs, HYPE flush bid, gold ~3,820, BTC 66K trigger. Bearish INTC/SPCX.
- **t_in_crypto:** 100% BTC long @58.4K, diamond-handing; thinks the Jul 14–15 new moon won't deliver the expected candle.
- **Wild_Randomness:** Equities/vol — SPY averaging in, KOSPI/EWY bid 6800–7100, LIT long, out of NVDA; SPX "spot up vol up then broader top."
- **bull_genius / swarmister / Stoiiic:** flat/patient; bull_genius bearish HYPE near-term; swarmister intraday BTC long-lean; Stoiiic neutral (60–62 weekly pivot).

## Open Calibration Items
None — Discord window 06-13→06-16 had no ambiguous/pending items.

## Key Lessons
- twitterapi.io wraps tweets as `.data.tweets[]`, NOT `.tweets[]` — always use the correct path in prefetch scripts
- Always `git push` before `gh workflow run` — GA executes from remote `main`, not local HEAD
- Digest format: Markdown with clickable links, under 4000 chars
- Always save files AND commit before logging

## Recent Logs
- [2026-07-14](logs/2026-07-14.md) — trader-bootstrap force 7-day re-run (both platforms populated: 248 tweets + 1,133 Discord); full state rebuild, Killa 2x long @62.6K, HCH short basket + SPCX, t_in_crypto 100% long @58.4K, Chase flat, BTC grinding low-60Ks
- [2026-06-16](logs/2026-06-16.md) — trader-bootstrap force re-run (Discord-only, X cache empty); refreshed 3 Discord traders, BTC into 66–67k, HCH de-risking + new SPCX/TAO/XPL/TON shorts, Killa HTF-bull, Chase flat
- [2026-06-08](logs/2026-06-08.md) — X bootstrap root cause fixed; full trader state seeded (Discord + X); Worker deployed; all systems green
- [2026-06-06](logs/2026-06-06.md)
- [2026-06-05](logs/2026-06-05.md)
