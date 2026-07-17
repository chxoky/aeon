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

## Current Trader Posture (summary, 2026-07-17, last updated 15:41 UTC)
> BTC consolidating low-to-mid 60Ks (−53% off cycle high); 62K weekly pivot zone (HCH confirms "already big on gains 62k reached"); Structural bulls (KillaXBT/t_in_crypto HTF longs) vs tactical bears (HCH short basket 35% allocation); consensus = near-term chop/downside, HTF bottom "close." Recent: scalp-short hedge profit-taking (KillaXBT TP'd 50% of ladder). Equities: AI/semis momentum exhausted (HCH sarcastic "full crypto experience" on SNDK/MU/MRVL volatility). SPX near-term UP, bigger-picture cautious/top-watch.
- **KillaXBT:** HTF-bull BTC maxi. Holds **2x BTC swing long @62.6K + spot**; scalp-short hedge (64.8-65.8K ladder entry Jul 14) now 50% remaining (took profit 2× tranches). Expects final capitulation wick ~49-56K marks bottom. SOL "never sees ATH again."
- **HeartCanHodl:** Bearish. **Short basket BTC/ETH/SOL/HYPE/ZEC** (35% portfolio allocation, added Jul 14-15). Winning positions; 62K level confirmed "already big on gains". New: SNDK long 1366 (SNDK bounce played). Sentiment: cautious/patience on TP windows.
- **Crypto_Chase:** FLAT crypto (TP'd SNDK/MU in profit Jul 16). New: MU entry ~800 Jul 17, pending SNDK approval 1366, ES long watching. Watchlist: gold ~3,820, BTC 66K trigger. Bearish INTC.
- **t_in_crypto:** 100% BTC long @58.4K + x2 volume conviction add @62K (Jul 14), diamond-handing. Holds 67–71K upside target, 48K/44K support levels. Latest: Jul 17 15:41 cryptic post "Follow me or play against me 🤷🏻‍♀️ $btc" (ambiguous/calibration pending).
- **Wild_Randomness:** Equities/vol — SPY averaging, KOSPI/EWY watching 6800–7100, LIT long, out of NVDA. Macro bearish-majors view.
- **bull_genius / swarmister / Stoiiic:** varied; bull_genius nibbling BTC/HYPE support zones; swarmister HTF bullish BTC (posted 07:09Z LT long 70.7K target, ETH 2K); Stoiiic neutral-to-cautious (60–62K pivot, prior precarious assessment 01:04Z).

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
