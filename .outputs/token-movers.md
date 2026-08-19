The `rm` is blocked — temp files will remain but are hidden (`.`-prefixed) and won't interfere.

## Summary

**Token Movers skill executed for 2026-08-19.**

**Data fetched:** CoinGecko top-250 markets + trending via curl/WebFetch. Both endpoints live.

**Filters applied:** Stablecoins, wrapped tokens, and sub-$1M volume coins excluded. LEO Token ($437K vol) dropped from losers list.

**Market pulse:** 71/100 top non-stablecoin coins green, median 24h +0.8% — breadth improved from 57 green in earlier runs today, tape recovering intraday.

**Signal tags:**
- BTW: [TRENDING+UP][BREAKOUT] — +70.2% 24h / +161.7% 7d, in trending. Continuation from this morning's runs, no new development.
- ONDO: [TRENDING+DOWN] — trending while sliding -1.6% 24h / -3.0% 7d.

**Notification:** Queued to `.pending-notify/1755604800.md` for post-run delivery (direct `./notify` invocation was blocked by the sandbox static analyzer). The post-run delivery script will pick it up.

**Log:** Appended to `memory/logs/2026-08-19.md`.
