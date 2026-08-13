import json, math

with open('/home/runner/work/aeon/aeon/cg_markets.json') as f:
    markets = json.load(f)

with open('/home/runner/work/aeon/aeon/cg_trending.json') as f:
    trending_data = json.load(f)

# Stablecoin IDs to exclude
STABLECOIN_IDS = {
    'tether', 'usd-coin', 'dai', 'first-digital-usd', 'usde', 'tusd', 'usdd', 'pyusd',
    'fdusd', 'paxg', 'frax', 'true-usd', 'usds', 'ethena-usde', 'binance-peg-busd',
    'binance-usd', 'usdb', 'usdx', 'usdr', 'cusd', 'usdbr'
}

def is_stablecoin(coin):
    if coin['id'].lower() in STABLECOIN_IDS:
        return True
    sym = coin['symbol'].upper()
    if any(sym.startswith(p) for p in ('USD', 'EUR', 'GBP')):
        return True
    if 'stablecoin' in coin['name'].lower():
        return True
    price = coin.get('current_price', 0) or 0
    chg = abs(coin.get('price_change_percentage_24h_in_currency', 0) or 0)
    if 0.97 <= price <= 1.03 and chg < 0.5:
        return True
    return False

def is_wrapped_dupe(coin):
    sym = coin['symbol'].lower()
    return sym in ('wbtc', 'weth', 'steth', 'wsteth', 'weeth', 'reth', 'cbeth', 'bwbtc', 'ezeth')

# Filter
filtered = []
for c in markets:
    if is_stablecoin(c):
        continue
    if is_wrapped_dupe(c):
        continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000:
        continue
    filtered.append(c)

print(f"Total coins after filter: {len(filtered)}")

# Sort by 24h change
def get_24h(c):
    return c.get('price_change_percentage_24h_in_currency') or c.get('price_change_percentage_24h') or 0

sorted_by_24h = sorted(filtered, key=lambda c: get_24h(c), reverse=True)

winners = sorted_by_24h[:10]
losers = list(reversed(sorted_by_24h[-10:]))

# Market pulse
top100 = filtered[:100]
n_green = sum(1 for c in top100 if get_24h(c) > 0)
changes_top50 = sorted([get_24h(c) for c in filtered[:50]])
median_50 = changes_top50[25] if len(changes_top50) >= 50 else 0

print(f"\nMarket pulse: {n_green}/100 green, median top-50 change: {median_50:.1f}%")

# Trending coins top 7
trending_coins = []
for item in trending_data.get('coins', [])[:7]:
    d = item['item']
    price = d.get('data', {}).get('price', 0)
    change_24h_dict = d.get('data', {}).get('price_change_percentage_24h', {})
    change_24h = change_24h_dict.get('usd', 0) if isinstance(change_24h_dict, dict) else 0
    trending_coins.append({
        'name': d['name'],
        'symbol': d['symbol'],
        'rank': d.get('market_cap_rank') or 'N/A',
        'price': price,
        'change_24h': change_24h,
        'id': d['id']
    })

print("\nTrending:")
for t in trending_coins:
    print(f"  {t['symbol']} ({t['name']}) rank={t['rank']} price=${t['price']:.4f} 24h={t['change_24h']:+.1f}%")

trending_ids = {t['id'] for t in trending_coins}
trending_symbols = {t['symbol'].upper() for t in trending_coins}

def tag_coin(coin, is_trending):
    c24h = get_24h(coin)
    c7d = coin.get('price_change_percentage_7d_in_currency') or 0
    vol = coin.get('total_volume') or 0
    mcap = coin.get('market_cap') or 1
    rank = coin.get('market_cap_rank') or 999

    tags = []

    if is_trending and c24h > 0:
        tags.append('[TRENDING+UP]')
    elif is_trending and c24h < 0:
        tags.append('[TRENDING+DOWN]')

    if c24h > 15 and c7d > 25:
        tags.append('[BREAKOUT]')
    if c24h > 20 and c7d < 0:
        tags.append('[FADE]')
    if c24h < -10 and (vol / mcap) > 0.25:
        tags.append('[CAPITULATION]')
    if rank > 150 and c24h > 30:
        tags.append('[PUMP-RISK]')
    if mcap < 50_000_000:
        tags.append('[MICROCAP]')
    if rank <= 20:
        tags.append('[MAJOR]')

    return tags[:2]

def fmt_price(p):
    if p is None:
        return 'N/A'
    if p >= 1000:
        return f"${p:,.0f}"
    elif p >= 1:
        return f"${p:.3f}"
    elif p >= 0.01:
        return f"${p:.4f}"
    else:
        return f"${p:.6f}"

def fmt_vol(v):
    if v is None:
        return 'N/A'
    if v >= 1e9:
        return f"${v/1e9:.1f}B"
    elif v >= 1e6:
        return f"${v/1e6:.0f}M"
    return f"${v:,.0f}"

print("\n=== TOP 10 WINNERS ===")
for i, c in enumerate(winners, 1):
    is_t = c['id'] in trending_ids or c['symbol'].upper() in trending_symbols
    tags = tag_coin(c, is_t)
    c24 = get_24h(c)
    c7d = c.get('price_change_percentage_7d_in_currency') or 0
    c1h = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    rank = c.get('market_cap_rank') or 'N/A'
    mcap = c.get('market_cap') or 0
    print(f"  {i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(c['current_price'])}  {c24:+.1f}% / 7d {c7d:+.1f}% / 1h {c1h:+.1f}%  vol={fmt_vol(vol)} mcap={fmt_vol(mcap)} #{rank}  {' '.join(tags)}")

print("\n=== TOP 10 LOSERS ===")
for i, c in enumerate(losers, 1):
    is_t = c['id'] in trending_ids or c['symbol'].upper() in trending_symbols
    tags = tag_coin(c, is_t)
    c24 = get_24h(c)
    c7d = c.get('price_change_percentage_7d_in_currency') or 0
    c1h = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    rank = c.get('market_cap_rank') or 'N/A'
    mcap = c.get('market_cap') or 0
    print(f"  {i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(c['current_price'])}  {c24:+.1f}% / 7d {c7d:+.1f}% / 1h {c1h:+.1f}%  vol={fmt_vol(vol)} mcap={fmt_vol(mcap)} #{rank}  {' '.join(tags)}")

print("\n=== TRENDING ===")
for i, t in enumerate(trending_coins, 1):
    is_t = True
    is_winner = t['symbol'].upper() in [c['symbol'].upper() for c in winners]
    is_loser = t['symbol'].upper() in [c['symbol'].upper() for c in losers]
    c24 = t['change_24h']
    tag = '[TRENDING+UP]' if c24 > 0 else '[TRENDING+DOWN]'
    print(f"  {i}. {t['name']} ({t['symbol'].upper()}) — rank #{t['rank']}, {fmt_price(t['price'])}, 24h {c24:+.1f}%  {tag}")

print("\n=== NOTABLE (for reporting) ===")
notable = []
for c in winners + losers:
    is_t = c['id'] in trending_ids or c['symbol'].upper() in trending_symbols
    tags = tag_coin(c, is_t)
    c24 = get_24h(c)
    c7d = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 1
    rank = c.get('market_cap_rank') or 999
    if any(t in tags for t in ['[TRENDING+UP]', '[BREAKOUT]', '[CAPITULATION]', '[PUMP-RISK]']):
        vmcap = vol / mcap if mcap > 0 else 0
        notable.append((c['symbol'].upper(), c['name'], tags, c24, c7d, vol, mcap, rank, vmcap))

for sym, name, tags, c24, c7d, vol, mcap, rank, vmcap in notable:
    print(f"  {sym} ({name}) {' '.join(tags)} #{rank} 24h={c24:+.1f}% 7d={c7d:+.1f}% vol/mcap={vmcap:.2f}")
