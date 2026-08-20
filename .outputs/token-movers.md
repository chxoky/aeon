Done. The temp file will stay but doesn't affect anything. Here's the summary:

## Summary

**Token-movers run complete (2026-08-20 12:43 UTC).**

**What I did:**
- Read `memory/MEMORY.md` and last 2 days of logs to identify what was already reported (two earlier runs today: 07:00 UTC chain, 07:58 UTC standalone)
- Fetched live market data from CoinGecko (top 250 by mcap + trending) via curl + WebFetch fallback
- Filtered stablecoins and sub-$1M volume coins; applied signal tags

**Key findings vs this morning's runs:**
- **BOME** [PUMP-RISK]: +58.4%, rank 282, now trending — new high-manipulation signal not in morning reports
- **XRP** [MAJOR][TRENDING+UP]: escalated from +11.2% (07:00) → +17.9% (12:43) — mid-session acceleration
- **MON** (Monad) [TRENDING+UP]: +18.8%, rank 128, newly trending
- **LIT**: peaked +26.1% at 07:58, now +16.6% — 10pp pullback, fade risk developing
- **HYPE** [BREAKOUT]: holds +22.8% at $71.28 (HCH short at $60 still ~$11 underwater)
- Market pulse: overwhelmingly green, median ~+9%, no meaningful losers in top 250

**Files modified:**
- `memory/logs/2026-08-20.md` — log entry appended
- `.pending-notify/1787230653.md` — notification staged for post-run delivery (sandbox blocked direct send)
