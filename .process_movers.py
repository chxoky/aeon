#!/usr/bin/env python3
import json, sys

STABLECOINS = {
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd',
    'pyusd','fdusd','paxg','usds','ethena-usde','usual-usd',
    'frax','liquity-usd','crvusd','gusd','busd','susd','nusd',
    'true-usd','usd-plus','stasis-euro','terra-luna',
}
STABLE_SYM_PREFIX = ('usd','eur','gbp','usdt','usdc','busd','dai')
WRAPPED = {'wbtc','weth','steth','cbeth','reth','wsteth','weeth','beth'}

with open('/home/runner/work/aeon/aeon/.markets.json') as f:
    raw = json.load(f)
with open('/home/runner/work/aeon/aeon/.trending.json') as f:
    trending_data = json.load(f)

# Filter
def is_stable(c):
    cid = c['id'].lower()
    sym = c['symbol'].lower()
    name = c['name'].lower()
    if cid in STABLECOINS: return True
    if any(sym.startswith(p) for p in STABLE_SYM_PREFIX) and c['market_cap_rank'] and c['market_cap_rank'] <= 30:
        return True
    if 'stablecoin' in name or 'staked-ether' in name: return True
    return False

def is_wrapped(c):
    return c['symbol'].lower() in WRAPPED

filtered = []
for c in raw:
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    if is_stable(c): continue
    if is_wrapped(c): continue
    filtered.append(c)

# Sort for winners/losers
def pct24(c): return c.get('price_change_percentage_24h') or 0
def pct7(c): return c.get('price_change_percentage_7d_in_currency') or 0
def pct1(c): return c.get('price_change_percentage_1h_in_currency') or 0

sorted_asc = sorted(filtered, key=pct24)
losers = sorted_asc[:10]
winners = sorted_asc[-10:][::-1]

# Trending
trending_ids = set()
trending_coins = []
for item in trending_data.get('coins', [])[:7]:
    it = item['item']
    trending_ids.add(it['id'])
    price_data = it.get('data', {})
    price_str = price_data.get('price', 'N/A')
    pct24_trending = price_data.get('price_change_percentage_24h', {}).get('usd', None)
    trending_coins.append({
        'id': it['id'],
        'name': it['name'],
        'symbol': it['symbol'],
        'rank': it.get('market_cap_rank', 'N/A'),
        'price': price_str,
        'pct24': pct24_trending,
    })

winner_ids = {c['id'] for c in winners}
loser_ids = {c['id'] for c in losers}

def tags(c, is_trending):
    t = []
    p24 = pct24(c)
    p7 = pct7(c)
    rank = c.get('market_cap_rank') or 999
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0

    if is_trending and c['id'] in winner_ids:
        t.append('[TRENDING+UP]')
    if is_trending and c['id'] in loser_ids:
        t.append('[TRENDING+DOWN]')

    if not t:
        if p24 > 15 and p7 > 25:
            t.append('[BREAKOUT]')
        elif p24 > 20 and p7 < 0:
            t.append('[FADE]')

    if not t:
        if p24 < -10 and mcap > 0 and vol / mcap > 0.25:
            t.append('[CAPITULATION]')

    if rank > 150 and p24 > 30:
        if '[PUMP-RISK]' not in t:
            t.append('[PUMP-RISK]')

    if mcap < 50_000_000 and '[MICROCAP]' not in t:
        t.append('[MICROCAP]')
    elif rank <= 20 and '[MAJOR]' not in t:
        t.append('[MAJOR]')

    return ' '.join(t[:2])

def fmt_price(p):
    if p is None: return 'N/A'
    if p >= 1000: return f'${p:,.0f}'
    if p >= 1: return f'${p:.4g}'
    if p >= 0.01: return f'${p:.4f}'
    return f'${p:.6f}'

def fmt_vol(v):
    if v is None: return 'N/A'
    if v >= 1e9: return f'${v/1e9:.1f}B'
    if v >= 1e6: return f'${v/1e6:.0f}M'
    return f'${v/1e3:.0f}K'

def fmt_pct(p):
    if p is None: return 'N/A'
    sign = '+' if p >= 0 else ''
    return f'{sign}{p:.1f}%'

# Market pulse (top 100 filtered, after our filter)
top100 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
green = sum(1 for c in top100 if pct24(c) > 0)
total100 = len(top100)
sorted_top50 = sorted([c for c in filtered if (c.get('market_cap_rank') or 999) <= 50], key=pct24)
median_idx = len(sorted_top50) // 2
median_24h = pct24(sorted_top50[median_idx]) if sorted_top50 else 0

# Build output
lines = []

# Pulse
red_count = total100 - green
if green > red_count and median_24h > 1:
    pulse = f"Risk-on tape — {green}/{total100} top coins green, median {fmt_pct(median_24h)}; alts leading with broad participation."
elif red_count > green and median_24h < -1:
    pulse = f"Risk-off — {red_count}/{total100} top coins red, median {fmt_pct(median_24h)}; selling pressure across the board."
elif abs(median_24h) <= 1:
    pulse = f"Quiet tape — median move {fmt_pct(median_24h)} across top 50; choppy with no clear directional bias."
else:
    pulse = f"Mixed tape — {green}/{total100} top coins green, median {fmt_pct(median_24h)}; rotation active."

lines.append(pulse)
lines.append('')

# Winners
lines.append('TOP WINNERS (24h):')
for i, c in enumerate(winners, 1):
    is_t = c['id'] in trending_ids
    tag = tags(c, is_t)
    lines.append(
        f"{i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(c['current_price'])}  "
        f"{fmt_pct(pct24(c))} / 7d {fmt_pct(pct7(c))} / 1h {fmt_pct(pct1(c))}  •  "
        f"{fmt_vol(c.get('total_volume'))} / #{c.get('market_cap_rank','?')}  {tag}"
    )

lines.append('')
lines.append('TOP LOSERS (24h):')
for i, c in enumerate(losers, 1):
    is_t = c['id'] in trending_ids
    tag = tags(c, is_t)
    lines.append(
        f"{i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(c['current_price'])}  "
        f"{fmt_pct(pct24(c))} / 7d {fmt_pct(pct7(c))} / 1h {fmt_pct(pct1(c))}  •  "
        f"{fmt_vol(c.get('total_volume'))} / #{c.get('market_cap_rank','?')}  {tag}"
    )

lines.append('')
lines.append('TRENDING:')
for i, t in enumerate(trending_coins, 1):
    # Find in filtered for tag
    match = next((c for c in filtered if c['id'] == t['id']), None)
    tag = ''
    if match:
        is_t = True
        tag = tags(match, is_t)
    pct_str = fmt_pct(t['pct24']) if t['pct24'] is not None else 'N/A'
    price_str = t['price'] if isinstance(t['price'], str) else fmt_price(float(str(t['price']).replace('$','').replace(',','')))
    lines.append(f"{i}. {t['name']} ({t['symbol'].upper()}) — #{t['rank']}, {price_str}, 24h {pct_str}  {tag}")

# Notable section
notable = []
for c in winners + losers:
    is_t = c['id'] in trending_ids
    tag = tags(c, is_t)
    p24 = pct24(c)
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 1
    if '[TRENDING+UP]' in tag:
        notable.append(f"• {c['symbol'].upper()}: trending + up {fmt_pct(p24)} — strong signal convergence")
    if '[BREAKOUT]' in tag:
        notable.append(f"• {c['symbol'].upper()}: {fmt_pct(p24)} / 7d {fmt_pct(pct7(c))} — sustained breakout, not a flash")
    if '[CAPITULATION]' in tag:
        notable.append(f"• {c['symbol'].upper()}: {fmt_pct(p24)} on ~{vol/mcap:.1%} vol/mcap ratio — capitulation signal")
    if '[PUMP-RISK]' in tag:
        notable.append(f"• {c['symbol'].upper()}: #{c.get('market_cap_rank','?')} rank, {fmt_pct(p24)} — PUMP-RISK, low-cap manipulation probable")
for t in trending_coins:
    match = next((c for c in filtered if c['id'] == t['id']), None)
    if match:
        tag = tags(match, True)
        if '[TRENDING+DOWN]' in tag:
            notable.append(f"• {match['symbol'].upper()}: trending while down {fmt_pct(pct24(match))} — capitulation / bad-news signal")

if notable:
    lines.append('')
    lines.append('NOTABLE:')
    for n in notable[:4]:
        lines.append(n)

# Also print log-format summary
lines.append('')
lines.append('---LOG---')
lines.append(pulse)
winner_str = ', '.join(f"{c['symbol'].upper()} ({fmt_pct(pct24(c))})" for c in winners[:5])
loser_str = ', '.join(f"{c['symbol'].upper()} ({fmt_pct(pct24(c))})" for c in losers[:5])
trend_str = ', '.join(t['symbol'].upper() for t in trending_coins[:5])
notable_log = '; '.join(n.lstrip('• ') for n in notable[:2]) if notable else 'none'
lines.append(f"Winners: {winner_str}")
lines.append(f"Losers: {loser_str}")
lines.append(f"Trending: {trend_str}")
lines.append(f"Notable: {notable_log}")

print('\n'.join(lines))
