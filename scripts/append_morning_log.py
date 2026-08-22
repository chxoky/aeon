with open('/home/runner/work/aeon/aeon/memory/logs/2026-08-22.md', 'a') as f:
    f.write("""
---

### market-context-refresh
- Regime: risk-on, alt rotation (conviction high)
- BTC: $77,347 (+2.8%), ETH: $2,433 (+3.0%), SOL: $94.43 (+3.9%), F&G: 71 (Greed)
- Breadth: ~17/20 green 24h (est.)
- BTC dominance: 58.58% (-0.68pp -- alt outperformance)
- DEX vol: $13.9B (+32% day-on-day)
- Top narrative: ZEC breakout (rising, $808 +33.4% 24h; Stoiiic + trading_axe catalyst)
- Polymarket: Fed No Change Sep 68.5%; Fed +25bps Sep 30.5%
- Source status: coingecko=ok defillama=ok fng=ok polymarket=ok websearch=ok
- Updated memory/topics/market-context.md; sent notification via ./notify

### token-movers
- Var: none
- Pulse: Alt rotation accelerating -- BTC dominance fell 0.68pp as XRP/ZEC/HYPE/memes posted 10-70% 24h; DEX vol $13.9B (+32%)
- Winners: TRUMP (+68.7%), ZEC (+33.4%), PEPE (+22.7%), XRP (+19.7%), PUMP (+19.1%), LIT (+13.4%), SUI (+11.7%), HYPE (+9.9%), BNB (+5.4%), SOL (+3.9%)
- Losers: tape near-universally green; PIPEDOG (#691) -10.9% only qualifying
- Notable: ZEC [MAJOR][BREAKOUT][TRENDING+UP]; HYPE ATH breached [MAJOR][BREAKOUT]; XRP [MAJOR][BREAKOUT]
- Sent notification via ./notify

### morning-brief
- Focus 1: HYPE $79.76 (ATH breached) -- HCH short >33% underwater, cover signal pending
- Focus 2: ZEC $808 (+33% 24h) -- Stoiiic/trading_axe catalyst pre-move; source unnamed
- Focus 3: Jackson Hole T-5 (Aug 27) -- BTC $77.3K entering; Powell tone = Q3 path
- Headlines: ETF $800M Aug 21 (6-day streak) -- updates focus 3
- Skills flagged: none (no open issues; no cron-state.json)
- Sent notification via ./notify
- Resend email: skipped (BRIEF_RECIPIENTS/RESEND_API_KEY not accessible in sandbox)
""")
print("done")
