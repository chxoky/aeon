import json, sys

data = json.load(sys.stdin)

STABLECOIN_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','staked-ether','wrapped-steth'}
WRAPPED = {'wrapped-bitcoin','wrapped-ethereum','weth','lido-staked-ether'}

filtered = []
for c in data:
    if c['id'] in STABLECOIN_IDS: continue
    if c['id'] in WRAPPED: continue
    sym = (c['symbol'] or '').lower()
    name = (c['name'] or '').lower()
    if sym.startswith(('usd','eur','gbp')): continue
    if any(w in name for w in ('stablecoin','pegged usd')): continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    filtered.append(c)

winners = sorted([c for c in filtered if (c.get('price_change_percentage_24h_in_currency') or 0) > 0], key=lambda x: x.get('price_change_percentage_24h_in_currency',0), reverse=True)[:10]
losers = sorted([c for c in filtered if (c.get('price_change_percentage_24h_in_currency') or 0) < 0], key=lambda x: x.get('price_change_percentage_24h_in_currency',0))[:10]

top100 = filtered[:100]
green = sum(1 for c in top100 if (c.get('price_change_percentage_24h_in_currency') or 0) > 0)
changes_top50 = sorted([c.get('price_change_percentage_24h_in_currency',0) or 0 for c in filtered[:50]])
median_50 = changes_top50[25]

print(f'PULSE|{green}|{median_50:.2f}')

def fmt_vol(v):
    if v >= 1e9: return f'${v/1e9:.1f}B'
    if v >= 1e6: return f'${v/1e6:.0f}M'
    return f'${v:,.0f}'

def fmt_price(p):
    if p >= 1: return f'${p:,.4g}'
    if p >= 0.01: return f'${p:.4f}'
    return f'${p:.6f}'

def compute_tags(c, trending_ids=None):
    d24 = c.get('price_change_percentage_24h_in_currency') or 0
    d7 = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mc = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 0
    vol_ratio = vol/mc if mc > 0 else 0
    tags = []
    if trending_ids and c['id'] in trending_ids:
        if d24 > 0: tags.append('TRENDING+UP')
        else: tags.append('TRENDING+DOWN')
    if rank <= 20 and 'TRENDING+UP' not in tags and 'TRENDING+DOWN' not in tags:
        tags.append('MAJOR')
    if mc < 50_000_000 and len(tags) < 2:
        tags.append('MICROCAP')
    if d24 > 15 and d7 > 25 and len(tags) < 2:
        tags.append('BREAKOUT')
    if d24 > 20 and d7 < 0 and 'BREAKOUT' not in tags and len(tags) < 2:
        tags.append('FADE')
    if rank > 150 and d24 > 30 and len(tags) < 2:
        tags.append('PUMP-RISK')
    if d24 < -10 and vol_ratio > 0.25 and len(tags) < 2:
        tags.append('CAPITULATION')
    return tags[:2]

print('WINNERS')
for i, c in enumerate(winners, 1):
    h1 = c.get('price_change_percentage_1h_in_currency') or 0
    d24 = c.get('price_change_percentage_24h_in_currency') or 0
    d7 = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mc = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 0
    price = c.get('current_price') or 0
    tags = compute_tags(c)
    tag_str = ' '.join(f'[{t}]' for t in tags)
    print(f'{i}|{c["symbol"].upper()}|{c["name"]}|{rank}|{fmt_price(price)}|{d24:+.1f}%|{d7:+.1f}%|{h1:+.1f}%|{fmt_vol(vol)}|{tag_str}')

print('LOSERS')
for i, c in enumerate(losers, 1):
    h1 = c.get('price_change_percentage_1h_in_currency') or 0
    d24 = c.get('price_change_percentage_24h_in_currency') or 0
    d7 = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mc = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 0
    price = c.get('current_price') or 0
    tags = compute_tags(c)
    tag_str = ' '.join(f'[{t}]' for t in tags)
    print(f'{i}|{c["symbol"].upper()}|{c["name"]}|{rank}|{fmt_price(price)}|{d24:+.1f}%|{d7:+.1f}%|{h1:+.1f}%|{fmt_vol(vol)}|{tag_str}')
