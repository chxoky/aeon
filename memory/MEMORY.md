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
- **GitHub Actions cron:** still enabled as secondary fallback (`*/15` each)

## Active Topics
- [Trader State](topics/traders.md) — All 12 traders, current positions, last seen timestamps. Rebuilt by `trader-x-bootstrap` 2026-06-08 (183 tweets, 3-day lookback). Fully seeded — both X + Discord state live.
- [Ticker Focus](topics/ticker-focus.md) — Overlap/contested tickers across traders, Kyle's explicit watch list, X-sourced equities.
- [Market Context](topics/market-context.md) — Latest regime snapshot, BTC price, F&G index.
- [Skill of the Day](topics/skill-of-the-day.md) — Most recent SOTD output.

## Current Trader Posture (summary, 2026-06-08 ~16:15Z)
- **HeartCanHodl:** Most active. Aggressively building a short basket: ZEC/HYPE/VVV/LAB/WLD/BIO + stock shorts MU/SNDK. BTC <63k = favorable, <60k = freefall. Thesis: "hunting for ltf weakness."
- **KillaXBT:** HTF-bullish BTC accumulation (~90% in), eyes 160K. LTF scalp-shorting "grey box" with small/low-risk size. Split-timeframe view.
- **Crypto_Chase:** FLAT. Gold stopped out 06-08T11:57Z. HYPE/NVDA previously cut. Conservative, waiting for clean setups. Not sure "what the actual trade is right now."

## Open Calibration Items
None — all 2026-06-08 items resolved.

## Key Lessons
- twitterapi.io wraps tweets as `.data.tweets[]`, NOT `.tweets[]` — always use the correct path in prefetch scripts
- Always `git push` before `gh workflow run` — GA executes from remote `main`, not local HEAD
- Digest format: Markdown with clickable links, under 4000 chars
- Always save files AND commit before logging

## Recent Logs
- [2026-06-08](logs/2026-06-08.md) — X bootstrap root cause fixed; full trader state seeded (Discord + X); Worker deployed; all systems green
- [2026-06-06](logs/2026-06-06.md)
- [2026-06-05](logs/2026-06-05.md)
