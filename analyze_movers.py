import json

with open('markets_raw.json') as f:
    markets = json.load(f)
with open('trending_raw.json') as f:
    trending_raw = json.load(f)

print(f"Markets loaded: {len(markets)} coins")

STABLE_IDS = {
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd',
    'fdusd','paxg','true-usd','frax','mim','liquity-usd','ethena-usde','usual-usd',
    'sky-dollar','gemini-dollar','celo-dollar','neutrino','frax-share'
}
STABLE_SYM_PREFIX = ('USD','EUR','GBP','AUD','CAD')
WRAPPED_IDS = {'wrapped-bitcoin','wrapped-ether','staked-ether','wrapped-steth','wsteth','lido-staked-ether'}

def is_stablecoin(c):
    if c['id'] in STABLE_IDS:
        return True
    if c['id'] in WRAPPED_IDS:
        return True
    sym = c['symbol'].upper()
    for pfx in STABLE_SYM_PREFIX:
        if sym.startswith(pfx):
            return True
    name = c['name'].lower()
    if 'stablecoin' in name:
        return True
    return False

filtered = []
for c in markets:
    if is_stablecoin(c):
        continue
    vol = c.get('total_volume') or 0
    if vol < 1000000:
        continue
    filtered.append(c)

print(f"After filter: {len(filtered)} coins")

sorted_24h = sorted(filtered, key=lambda c: c.get('price_change_percentage_24h') or 0, reverse=True)
winners = sorted_24h[:10]
losers = list(reversed(sorted_24h[-10:]))

trending_coins = trending_raw.get('coins', [])
trending_ids = set()
trending_list = []
for t in trending_coins[:7]:
    item = t.get('item', t)
    tid = item.get('id', '')
    trending_ids.add(tid)
    data = item.get('data', {})
    pcp = data.get('price_change_percentage_24h', {})
    if isinstance(pcp, dict):
        ch24 = pcp.get('usd')
    else:
        ch24 = pcp
    trending_list.append({
        'id': tid,
        'name': item.get('name', ''),
        'symbol': item.get('symbol', ''),
        'rank': item.get('market_cap_rank', '?'),
        'price': data.get('price', item.get('price', '?')),
        'change_24h': ch24,
    })

print("Trending IDs:", [t['id'] for t in trending_list])

top100 = sorted(filtered, key=lambda c: c.get('market_cap_rank') or 9999)[:100]
green = sum(1 for c in top100 if (c.get('price_change_percentage_24h') or 0) > 0)
red = sum(1 for c in top100 if (c.get('price_change_percentage_24h') or 0) < 0)
changes50 = sorted([c.get('price_change_percentage_24h') or 0 for c in top100[:50]])
median_50 = changes50[25] if len(changes50) > 25 else 0

print(f"Market pulse: {green}/100 green, {red}/100 red, median top-50: {median_50:.1f}%")

def tag(c):
    tags = []
    rank = c.get('market_cap_rank') or 9999
    ch24 = c.get('price_change_percentage_24h') or 0
    ch7d = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    cid = c.get('id', '')

    in_trending = cid in trending_ids

    if in_trending and ch24 > 0:
        tags.append('[TRENDING+UP]')
    if in_trending and ch24 < 0:
        tags.append('[TRENDING+DOWN]')
    if ch24 > 15 and ch7d > 25:
        tags.append('[BREAKOUT]')
    if ch24 > 20 and ch7d < 0:
        tags.append('[FADE]')
    if ch24 < -10 and mcap > 0 and vol / mcap > 0.25:
        tags.append('[CAPITULATION]')
    if rank > 150 and ch24 > 30:
        tags.append('[PUMP-RISK]')
    if mcap < 50000000 and mcap > 0:
        tags.append('[MICROCAP]')
    if rank <= 20:
        tags.append('[MAJOR]')

    return tags[:2]

def fmt_price(p):
    if p is None:
        return '?'
    try:
        p = float(p)
    except Exception:
        return str(p)
    if p >= 1:
        return f"${p:,.4g}"
    if p >= 0.01:
        return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_vol(v):
    if v is None:
        return '?'
    if v >= 1e9:
        return f"${v/1e9:.1f}B"
    if v >= 1e6:
        return f"${v/1e6:.0f}M"
    return f"${v:,.0f}"

print("\n=== TOP WINNERS ===")
for i, c in enumerate(winners, 1):
    tags = tag(c)
    ch24 = c.get('price_change_percentage_24h') or 0
    ch7d = c.get('price_change_percentage_7d_in_currency') or 0
    ch1h = c.get('price_change_percentage_1h_in_currency') or 0
    tag_str = ' '.join(tags)
    print(f"{i}. {c['symbol'].upper()} ({c['name']}) -- {fmt_price(c['current_price'])}  +{ch24:.1f}% / 7d {ch7d:+.1f}% / 1h {ch1h:+.1f}%  *  {fmt_vol(c['total_volume'])} / #{c['market_cap_rank']}  {tag_str}")

print("\n=== TOP LOSERS ===")
for i, c in enumerate(losers, 1):
    tags = tag(c)
    ch24 = c.get('price_change_percentage_24h') or 0
    ch7d = c.get('price_change_percentage_7d_in_currency') or 0
    ch1h = c.get('price_change_percentage_1h_in_currency') or 0
    tag_str = ' '.join(tags)
    print(f"{i}. {c['symbol'].upper()} ({c['name']}) -- {fmt_price(c['current_price'])}  {ch24:.1f}% / 7d {ch7d:+.1f}% / 1h {ch1h:+.1f}%  *  {fmt_vol(c['total_volume'])} / #{c['market_cap_rank']}  {tag_str}")

print("\n=== TRENDING ===")
for i, t in enumerate(trending_list, 1):
    pfmt = fmt_price(t['price'])
    ch = t['change_24h']
    chfmt = f"{float(ch):+.1f}%" if ch is not None else '?'
    market_match = next((c for c in filtered if c['id'] == t['id']), None)
    extra_tags = tag(market_match) if market_match else []
    tag_str = ' '.join(extra_tags)
    print(f"{i}. {t['name']} ({t['symbol']}) -- #{t['rank']}, {pfmt}, 24h {chfmt}  {tag_str}")

print("\n=== NOTABLE ===")
winner_ids = {c['id'] for c in winners}
loser_ids = {c['id'] for c in losers}
notable = []
for c in winners + losers:
    tags = tag(c)
    key_tags = [t for t in tags if t in ['[TRENDING+UP]','[TRENDING+DOWN]','[BREAKOUT]','[CAPITULATION]','[PUMP-RISK]']]
    if key_tags:
        ch24 = c.get('price_change_percentage_24h') or 0
        notable.append(f"* {c['symbol'].upper()}: {' '.join(key_tags)} {ch24:+.1f}% #{c.get('market_cap_rank','?')}")
for t in trending_list:
    market_match = next((c for c in filtered if c['id'] == t['id']), None)
    if market_match:
        tags = tag(market_match)
        key_tags = [tg for tg in tags if tg in ['[TRENDING+UP]','[TRENDING+DOWN]','[BREAKOUT]','[PUMP-RISK]']]
        if key_tags and market_match['id'] not in winner_ids and market_match['id'] not in loser_ids:
            ch24 = market_match.get('price_change_percentage_24h') or 0
            notable.append(f"* {t['symbol']}: {' '.join(key_tags)} {ch24:+.1f}% #{market_match.get('market_cap_rank','?')}")
for n in notable:
    print(n)

print("\n=== BTC/ETH/SOL CHECK ===")
for c in markets:
    if c['id'] in ['bitcoin','ethereum','solana']:
        ch24 = c.get('price_change_percentage_24h') or 0
        ch7d = c.get('price_change_percentage_7d_in_currency') or 0
        print(f"{c['symbol'].upper()}: ${c['current_price']:,}  24h {ch24:+.1f}%  7d {ch7d:+.1f}%")
