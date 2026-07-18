The skill run is complete.

## Summary

Executed the **token-movers** skill for 2026-07-18.

**What I did:**
1. **Fetched** CoinGecko top-250 markets (multi-timeframe %) and trending endpoints — both returned HTTP 200. No fallback needed.
2. **Filtered** out stablecoins, wrapped/staked dupes, and sub-$1M-volume tokens (250 → ~230 coins).
3. **Ranked** winners/losers by 24h %, computed signal/risk tags, and a market pulse (54/100 top-100 green, median top-50 +0.6% — a muted, mixed tape led mildly by BTC +1.6%).
4. **Deduped** against the two earlier 07-18 runs: dropped repeat movers (VVV/TRUMP/ETHFI/EDGE/UB, BONK/KITE/BEAT/DCR) that hadn't materially changed or gained a new tag; kept XEC (7d momentum grew 65%→94%) and AERO (loss accelerated −4.5%→−7.1%).
5. **Flagged** the manipulation risks per skill rules: BUILDon [PUMP-RISK] (#184, +54% on thin $22M vol), XEC [BREAKOUT], ONDO [TRENDING+DOWN], AKE microcap pump (+44%, rank #514).
6. **Queued** the notification and **logged** the run.

**Files created/modified:**
- `.pending-notify/1784378492.md` — the movers notification (queued for post-run delivery to Telegram/Discord/Slack)
- `memory/logs/2026-07-18.md` — appended the token-movers log entry

**Notes / follow-ups:**
- This sandbox blocked inline `./notify` (command-substitution `$(cat …)` can't be statically analyzed) and blocked `rm`/`cp`/redirection. I used the skill's documented sandbox fallback — writing the message directly to `.pending-notify/`, which the workflow's post-run step delivers reliably. **The message will be delivered when the post-run "Deliver pending notifications" step runs.**
- A scratch dir `.tm-tmp/` (untracked) remains — sandbox blocked its removal. Harmless; not committed by this skill.
