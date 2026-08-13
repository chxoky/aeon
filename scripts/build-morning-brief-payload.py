#!/usr/bin/env python3
"""Build Resend email payload for morning brief and write to /tmp/morning-brief-payload.json"""
import json
import os
import sys

recipients_raw = os.environ.get("BRIEF_RECIPIENTS", "").strip()
if not recipients_raw:
    print("BRIEF_RECIPIENTS not set — skipping", file=sys.stderr)
    sys.exit(0)

recipients = [r.strip() for r in recipients_raw.split(",") if r.strip()]

html = """<html><body style="font-family:monospace;max-width:640px;margin:auto;padding:24px">
<h2>Morning Brief &#8212; 2026-08-13</h2>

<h3>Focus today</h3>
<ol>
  <li><strong>HCH net-short escalation</strong> &#8212; HYPE/LIT/PUMP shorts added; mirror decision window open now</li>
  <li><strong>ETH stand-down + WR binary</strong> &#8212; PPI in-line killed entry; 10-day clock to Aug 23 resolution</li>
  <li><em>background:</em> <strong>Chop regime confirmed</strong> &#8212; Fed ceiling 66.5%; no breakout catalyst in window</li>
</ol>

<h3>Since yesterday</h3>
<ul>
  <li>ETH 7d flipped negative (-0.8% from +2.2%); stand-down confirmed, entry thesis invalidated</li>
  <li>HCH: 3 new conviction shorts (HYPE/LIT/PUMP 1% each) + half spot longs covered + CL crude oil short opened</li>
  <li>KAITO [CAPITULATION] -26.9%; prior HCH/Stoiiic shorts now in profit</li>
  <li>WR posted ETH binary this morning: break or retest within 10 days (by Aug 23)</li>
  <li>DeFi TVL fading: Lido -0.42%, WBTC -1.14% 7d &#8212; accumulation narrative weakened</li>
</ul>

<h3>Watch</h3>
<ul>
  <li>Hyperliquid: 70% perp DEX share, $1.07M daily fee buyback &#8212; HCH shorting into structural strength; squeeze risk if HYPE holds above $57 &#8212; implication for Focus #1</li>
</ul>

<h3>Running today</h3>
<ul>
  <li>morning-pipeline @ 07:00 UTC (running now)</li>
  <li>market-context-refresh @ 10:00 UTC</li>
  <li>x-trader-monitor continuous</li>
  <li>discord-trader-monitor continuous</li>
  <li>heartbeat periodic</li>
</ul>

<hr><p style="color:#888;font-size:11px">Aeon autonomous agent &#8212; aeonframework</p>
</body></html>"""

payload = {
    "from": "Aeon Briefings <onboarding@resend.dev>",
    "to": recipients,
    "subject": "[Aeon] Morning Brief — 2026-08-13",
    "html": html,
}

with open("/tmp/morning-brief-payload.json", "w") as f:
    json.dump(payload, f)

print(f"Payload written for {len(recipients)} recipient(s): {recipients}")
