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

## Active Topics
- [Trader State](topics/traders.md) — All 12 traders, current positions, last seen timestamps. 3 Discord traders refreshed by `trader-bootstrap` 2026-06-16 (force re-run, Discord-only); 9 X-only sections STALE (06-08, X cache empty this run).
- [Ticker Focus](topics/ticker-focus.md) — Overlap/contested tickers across traders, Kyle's explicit watch list, X-sourced equities.
- [Market Context](topics/market-context.md) — Latest regime snapshot, BTC price, F&G index.
- [Skill of the Day](topics/skill-of-the-day.md) — Most recent SOTD output.

## Current Trader Posture (summary, 2026-06-16, trader-bootstrap force re-run)
> BTC rallied into 66–67k on the Iran peace-deal resolution + FOMC. X cache empty this run — Discord-only refresh.
- **HeartCanHodl:** De-risking both sides into strength — covered >50% of majors longs (BTC/ETH/SOL) by 67k while rebalancing a short basket: ZEC (adding), TAO, VVV, XPL, TON + NEW SpaceX/SPCX short. Contrarian "Ansem-fade" sentiment cue. "Bulls keep winning."
- **KillaXBT:** Still HTF-bullish — holds 2X BTC swing long + spot, "bear cycle ending." Also holding a small LTF scalp short filled 67.2K as a hedge into FOMC. Prior 64.7K scalp closed (25% TP @63.7K, rest BE).
- **Crypto_Chase:** FLAT. Resting bids front-run ~1% by the peace deal; waiting for a clean flush of his level to bid. Cautious on a broader bubble pop. Gold = main watch instrument.

## Open Calibration Items
None — Discord window 06-13→06-16 had no ambiguous/pending items.

## Key Lessons
- twitterapi.io wraps tweets as `.data.tweets[]`, NOT `.tweets[]` — always use the correct path in prefetch scripts
- Always `git push` before `gh workflow run` — GA executes from remote `main`, not local HEAD
- Digest format: Markdown with clickable links, under 4000 chars
- Always save files AND commit before logging

## Recent Logs
- [2026-06-16](logs/2026-06-16.md) — trader-bootstrap force re-run (Discord-only, X cache empty); refreshed 3 Discord traders, BTC into 66–67k, HCH de-risking + new SPCX/TAO/XPL/TON shorts, Killa HTF-bull, Chase flat
- [2026-06-08](logs/2026-06-08.md) — X bootstrap root cause fixed; full trader state seeded (Discord + X); Worker deployed; all systems green
- [2026-06-06](logs/2026-06-06.md)
- [2026-06-05](logs/2026-06-05.md)
