import urllib.request, json, sys

STABLECOINS = {
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
    'frax','usds','ethena-staked-usde','lido-staked-ether','rocket-pool-eth'
}
STABLE_SYMBOLS = {'USDT','USDC','DAI','FDUSD','TUSD','USDD','PYUSD','PAXG','FRAX','USDS','BUSD','GUSD','LUSD'}
WRAPPED = {'wbtc','weth','steth','cbeth','reth','weeth','rseth','ezeth','meth','susde','wbeth'}

def is_stable(c):
    if c['id'] in STABLECOINS: return True
    sym = c['symbol'].upper()
    if sym in STABLE_SYMBOLS: return True
    if sym.startswith('USD') or sym.startswith('EUR') or sym.startswith('GBP'): return True
    if 'stablecoin' in c['name'].lower(): return True
    return False

def fmt_price(price):
    if price is None: return '$0'
    if price >= 1: return f"${price:,.2f}"
    elif price >= 0.01: return f"${price:.4f}"
    else: return f"${price:.6f}"

def fmt_vol(v):
    if v is None: return '$0'
    if v >= 1e9: return f"${v/1e9:.1f}B"
    return f"${v/1e6:.0f}M"

# Fetch markets
url = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d"
with urllib.request.urlopen(url, timeout=30) as r:
    data = json.load(r)

# Fetch trending
url2 = "https://api.coingecko.com/api/v3/search/trending"
with urllib.request.urlopen(url2, timeout=30) as r:
    trending_raw = json.load(r)

# Filter markets
filtered = []
for c in data:
    if is_stable(c): continue
    if c['id'] in WRAPPED: continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    filtered.append(c)

def pct24(c):
    return c.get('price_change_percentage_24h_in_currency') or 0

winners = sorted(filtered, key=pct24, reverse=True)[:10]
losers = sorted(filtered, key=pct24)[:10]

winner_ids = {c['id'] for c in winners}
loser_ids = {c['id'] for c in losers}

# Market pulse
top100 = sorted(filtered, key=lambda c: c.get('market_cap_rank') or 999)[:100]
green_count = sum(1 for c in top100 if pct24(c) > 0)
pcts50 = sorted([pct24(c) for c in top100[:50]])
median_pct = pcts50[25] if len(pcts50) > 25 else 0

# Parse trending
trending_coins = []
for item in trending_raw.get('coins', [])[:7]:
    item_data = item.get('item', item)
    coin_id = item_data.get('id','')
    trending_coins.append({
        'id': coin_id,
        'name': item_data.get('name',''),
        'symbol': item_data.get('symbol',''),
        'rank': item_data.get('market_cap_rank', 0),
        'price': item_data.get('data', {}).get('price', 0),
        'pct24': item_data.get('data', {}).get('price_change_percentage_24h', {}).get('usd', 0),
    })

trending_ids = {c['id'] for c in trending_coins}

def get_tags_winner(c):
    p24 = pct24(c)
    p7 = c.get('price_change_percentage_7d_in_currency') or 0
    rank = c.get('market_cap_rank') or 999
    mcap = c.get('market_cap') or 0
    tags = []
    if c['id'] in trending_ids and p24 > 0: tags.append('TRENDING+UP')
    if c['id'] in trending_ids and p24 < 0: tags.append('TRENDING+DOWN')
    if p24 > 15 and p7 > 25: tags.append('BREAKOUT')
    if p24 > 20 and p7 < 0: tags.append('FADE')
    if rank > 150 and p24 > 30: tags.append('PUMP-RISK')
    if mcap < 50_000_000: tags.append('MICROCAP')
    if rank <= 20: tags.append('MAJOR')
    return tags[:2]

def get_tags_loser(c):
    p24 = pct24(c)
    rank = c.get('market_cap_rank') or 999
    mcap = c.get('market_cap') or 0
    vol = c.get('total_volume') or 0
    vol_mcap_ratio = vol / mcap if mcap > 0 else 0
    tags = []
    if c['id'] in trending_ids and p24 < 0: tags.append('TRENDING+DOWN')
    if p24 < -10 and vol_mcap_ratio > 0.25: tags.append('CAPITULATION')
    if rank <= 20: tags.append('MAJOR')
    if mcap < 50_000_000: tags.append('MICROCAP')
    return tags[:2]

print(f"PULSE:{green_count}:{median_pct:.1f}")
print("WINNERS")
for c in winners:
    p24 = pct24(c)
    p7 = c.get('price_change_percentage_7d_in_currency') or 0
    p1 = c.get('price_change_percentage_1h_in_currency') or 0
    rank = c.get('market_cap_rank') or 0
    price = c.get('current_price') or 0
    vol = c.get('total_volume') or 0
    tags = get_tags_winner(c)
    tag_str = ' '.join(f'[{t}]' for t in tags) if tags else ''
    print(f"{c['symbol'].upper()}|{c['name']}|{fmt_price(price)}|{p24:.1f}|{p7:.1f}|{p1:.1f}|{fmt_vol(vol)}|{rank}|{tag_str}")

print("LOSERS")
for c in losers:
    p24 = pct24(c)
    p7 = c.get('price_change_percentage_7d_in_currency') or 0
    p1 = c.get('price_change_percentage_1h_in_currency') or 0
    rank = c.get('market_cap_rank') or 0
    price = c.get('current_price') or 0
    vol = c.get('total_volume') or 0
    tags = get_tags_loser(c)
    tag_str = ' '.join(f'[{t}]' for t in tags) if tags else ''
    print(f"{c['symbol'].upper()}|{c['name']}|{fmt_price(price)}|{p24:.1f}|{p7:.1f}|{p1:.1f}|{fmt_vol(vol)}|{rank}|{tag_str}")

print("TRENDING")
for c in trending_coins:
    in_winners = c['id'] in winner_ids
    in_losers = c['id'] in loser_ids
    cross = ''
    if in_winners: cross = '[TRENDING+UP]'
    elif in_losers: cross = '[TRENDING+DOWN]'
    price = c['price']
    p24 = c['pct24']
    rank = c['rank'] or 0
    if isinstance(price, (int, float)) and price > 0:
        price_str = fmt_price(price)
    else:
        price_str = str(price)
    p24_str = f"+{p24:.1f}%" if p24 > 0 else f"{p24:.1f}%"
    print(f"{c['name']}|{c['symbol'].upper()}|{rank}|{price_str}|{p24_str}|{cross}")
