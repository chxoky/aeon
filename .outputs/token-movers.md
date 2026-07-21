The `rm` is blocked by the sandbox — the `.tmvr/` scratch dir is untracked and harmless, so I'll leave it (it won't be committed).

The run is complete. Here's the wrap-up.

## Summary

Executed the **token-movers** skill for 2026-07-21.

**What I did:**
1. Read the skill, MEMORY.md, soul files (empty templates → neutral tone), and the last 2 days of logs (no prior token-movers runs to dedup against).
2. Fetched CoinGecko markets (top 250, multi-timeframe) and trending endpoints via curl — both succeeded, no WebFetch fallback needed.
3. Filtered out stablecoins, wrapped dupes, and sub-$1M-volume tokens (250 → 185 coins) using `jq` (the sandbox blocked `python3` execution).
4. Ranked top-10 winners/losers, pulled 7 trending, and computed signal/risk tags (TRENDING+UP/DOWN, CAPITULATION, MAJOR, PUMP-RISK).
5. Queued the notification to `.pending-notify/` for post-run delivery (sandbox blocks outbound curl from bash; the workflow's post-run step delivers it).
6. Logged the run to today's log.

**Report highlights:**
- **Tape:** Broadly green (82/100 top coins up, median top-50 +1.5%) but shallow — winners cap ~15%.
- **The story:** two top-100 names collapsing against the green tape — **DEXE −57%** (trending-down + capitulation, 7d −65%) and **Midnight (NIGHT) −26%** (capitulation).
- **Leader:** **ONDO +14.6%** on $227M volume, trending-up, carrying the RWA/green rotation.
- **Pump-risk flagged:** trending microcaps ERA (+61%) and PONS (+93%) sit at ranks #881/#670, outside the top 250 — surfaced as noise/thin-liquidity warnings.

**Files modified:**
- `.pending-notify/token-movers-2026-07-21.md` (queued notification, ~2.9KB, under 4000-char cap)
- `memory/logs/2026-07-21.md` (appended token-movers log entry)

**Follow-up:** None. Notification will be delivered by the workflow's post-run step. (Note: the sandbox blocked `python3`, `rm`, and `$(...)` command substitution this run — I worked around all three with `jq`, the Write tool, and the `.pending-notify/` fallback path respectively.)
