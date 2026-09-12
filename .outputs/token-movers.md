## Summary

**token-movers run aborted** due to CoinGecko rate limiting.

- The trending endpoint returned successfully (15 trending coins including AI +39%, ETHFI +15.4%, ZEC flat, BTC -0.8%, HYPE -2%)
- The `/coins/markets` endpoint returned HTTP 429 on every attempt (both curl and WebFetch), with Retry-After values ranging 11–59 seconds
- Per skill constraints: "Do not publish a partial or stale report" — a partial report without winners/losers is not allowed
- Abort notification sent via `./notify`
- Run logged to `memory/logs/2026-09-12.md`

**Root cause:** No `COINGECKO_API_KEY` secret is configured; the free-tier API has a low rate limit (typically ~30 req/min shared across all free users). Setting `COINGECKO_API_KEY` in repo secrets would use a Pro endpoint with higher limits and avoid this issue.
