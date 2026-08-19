#!/bin/bash
# One-shot: send morning brief email via secretcurl
# Called after morning-brief skill runs; RESEND_API_KEY and BRIEF_RECIPIENTS injected by workflow

SUBJECT="[Aeon] Morning Brief — 2026-08-19"

HTML='<html><body>
<h2>Focus today</h2>
<ol>
<li><strong>HYPE approve/skip</strong> — ryzzqq scaled longs live; entry at -2.4% and improving</li>
<li><strong>Aug 20 catalyst stack</strong> — Fed minutes + SPCX 2nd unlock + WR ETH arrow all hit tomorrow</li>
<li><strong>traders.md TRIPWIRE</strong> — compact failed Aug 16; active logging degrading at 299K</li>
</ol>
<h2>Since yesterday</h2>
<ul>
<li>[BTW] +68.9% / +179% 7d — isolated breakout, no GameFi breadth; day 2 accelerating</li>
<li>[HCH] 65% net short / 1.8x leverage; SOL short confirmed (2nd ticker pending calibration); CL add to 2% total</li>
<li>[ryzzqq] broke 19-day silence: HYPE scaled longs in + SPCX Aug 20 unlock dump warning</li>
<li>[WR] ETH Aug 20 arrow tracking + ES macro bear analog charts; conditional weekly bull plan (asset unclear)</li>
<li>[PUMP] day 6+ green, WR Crescendo? flag — exhaustion watch; F&G crept 41→46</li>
</ul>
<h2>Running today</h2>
<ul>
<li>x-trader-monitor: continuous</li>
<li>discord-trader-monitor: continuous</li>
<li>token-alert @ 12:00 UTC</li>
<li>token-movers @ 12:00 UTC</li>
<li>market-context-refresh @ 13:00 UTC</li>
<li>narrative-tracker @ 13:30 UTC</li>
</ul>
</body></html>'

TEXT='Morning Brief — 2026-08-19

Focus today
1. HYPE approve/skip — ryzzqq scaled longs live; entry at -2.4% and improving
2. Aug 20 catalyst stack — Fed minutes + SPCX 2nd unlock + WR ETH arrow all hit tomorrow
3. traders.md TRIPWIRE — compact failed Aug 16; active logging degrading at 299K

Since yesterday
- [BTW] +68.9% / +179% 7d — isolated breakout, no GameFi breadth; day 2 accelerating
- [HCH] 65% net short / 1.8x leverage; SOL short confirmed (2nd ticker pending calibration); CL add to 2% total
- [ryzzqq] broke 19-day silence: HYPE scaled longs in + SPCX Aug 20 unlock dump warning
- [WR] ETH Aug 20 arrow tracking + ES macro bear analog charts; conditional weekly bull plan (asset unclear)
- [PUMP] day 6+ green, WR Crescendo? flag — exhaustion watch; F&G crept 41→46

Running today
- x-trader-monitor: continuous
- discord-trader-monitor: continuous
- token-alert @ 12:00 UTC
- token-movers @ 12:00 UTC
- market-context-refresh @ 13:00 UTC
- narrative-tracker @ 13:30 UTC'

# Build JSON payload (jq handles escaping)
PAYLOAD=$(jq -n \
  --arg from "Aeon Briefings <onboarding@resend.dev>" \
  --arg to "{BRIEF_RECIPIENTS}" \
  --arg subject "$SUBJECT" \
  --arg html "$HTML" \
  --arg text "$TEXT" \
  '{from: $from, to: [$to], subject: $subject, html: $html, text: $text}')

./secretcurl -s -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer {RESEND_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
