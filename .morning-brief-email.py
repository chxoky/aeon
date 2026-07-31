#!/usr/bin/env python3
import os, json, subprocess, sys

recipients_raw = os.environ.get("BRIEF_RECIPIENTS", "")
if not recipients_raw.strip():
    print("BRIEF_RECIPIENTS not set — skipping email")
    sys.exit(0)

recipients = [r.strip() for r in recipients_raw.split(",") if r.strip()]

html = """<!DOCTYPE html><html><body>
<h2>Morning Brief &mdash; 2026-07-31</h2>
<h3>Focus today</h3>
<ol>
<li><strong>HCH short basket at ~50% allocation</strong> &mdash; why now: overnight adds uncovered; ADA mirror decision pending</li>
<li><strong>UNI +13.7% trending into HCH&rsquo;s 6% short</strong> &mdash; why now: contested position under active pressure right now</li>
<li><strong>7 pending calibrations from HCH, WR, new traders</strong> &mdash; why now: ambiguous signals stacking without your read</li>
</ol>
<h3>Since yesterday</h3>
<ul>
<li>[moved] Chase: MU/SNDK TP at 920/1380 &mdash; 65% closed, 35% core running</li>
<li>[moved] HCH: BTC/ETH/UNI/TAO/ADA shorts added across 96-min Asia session (01:50&ndash;03:29Z)</li>
<li>[moved] WR: SOXL 4-chart reversal confirmed; AAPL -7.8% intraday crash validated; ZEC broke 486 support</li>
<li>[moved] ryzzqq: SOL long stopped out at 74.2 (-1%); no Kraken mirror was live</li>
<li>[new] bull_genius: new tracked trader &mdash; contrarian HYPE/BTC long-term bullish; DCA target sub-50k BTC</li>
</ul>
<h3>Watch</h3>
<ul>
<li>Sep FOMC +25bps YES 52.5% on Polymarket ($426K vol) &mdash; macro tailwind for HCH&rsquo;s short basket thesis</li>
</ul>
<h3>Running today</h3>
<ul>
<li>heartbeat @ 08:00 UTC</li>
<li>token-alert, token-movers @ 12:00 UTC</li>
<li>market-context-refresh @ 13:00 UTC</li>
<li>narrative-tracker @ 13:30 UTC</li>
<li>skill-health @ 18:00 UTC</li>
</ul>
</body></html>"""

text = """Morning Brief — 2026-07-31

Focus today
1. HCH short basket at ~50% allocation — why now: overnight adds uncovered; ADA mirror decision pending
2. UNI +13.7% trending into HCH's 6% short — why now: contested position under active pressure right now
3. 7 pending calibrations from HCH, WR, new traders — why now: ambiguous signals stacking without your read

Since yesterday
- [moved] Chase: MU/SNDK TP at 920/1380 — 65% closed, 35% core running
- [moved] HCH: BTC/ETH/UNI/TAO/ADA shorts added across 96-min Asia session (01:50-03:29Z)
- [moved] WR: SOXL 4-chart reversal confirmed; AAPL -7.8% intraday crash validated; ZEC broke 486 support
- [moved] ryzzqq: SOL long stopped out at 74.2 (-1%); no Kraken mirror was live
- [new] bull_genius: new tracked trader — contrarian HYPE/BTC long-term bullish; DCA target sub-50k BTC

Watch
- Sep FOMC +25bps YES 52.5% on Polymarket ($426K vol) — macro tailwind for HCH's short basket thesis

Running today
- heartbeat @ 08:00 UTC
- token-alert, token-movers @ 12:00 UTC
- market-context-refresh @ 13:00 UTC
- narrative-tracker @ 13:30 UTC
- skill-health @ 18:00 UTC"""

payload = {
    "from": "Aeon Briefings <onboarding@resend.dev>",
    "to": recipients,
    "subject": "[Aeon] Morning Brief — 2026-07-31",
    "html": html,
    "text": text
}

body_path = ".morning-brief-email-body.json"
with open(body_path, "w") as f:
    json.dump(payload, f)

print(f"Payload written for {len(recipients)} recipient(s): {recipients}")
