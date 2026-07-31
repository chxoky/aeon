import urllib.request, json, sys

url1 = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d"
try:
    with urllib.request.urlopen(url1, timeout=30) as r:
        markets = json.loads(r.read())
    print(f"MARKETS_OK: {len(markets)} coins")
except Exception as e:
    print(f"MARKETS_ERR: {e}")
    sys.exit(1)

url2 = "https://api.coingecko.com/api/v3/search/trending"
try:
    with urllib.request.urlopen(url2, timeout=30) as r:
        trending_data = json.loads(r.read())
    trending_coins = trending_data.get('coins', [])
    print(f"TRENDING_OK: {len(trending_coins)} trending")
except Exception as e:
    print(f"TRENDING_WARN: {e}")
    trending_coins = []

STABLE_IDS = set([
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
    'usds','frax','ethena-usde','paypal-usd','true-usd','gusd','nusd','sai','ousd',
    'crvusd','dola','lusd','mim','rai','usdb','susd'
])
STABLE_SYMS = set(['usdt','usdc','dai','busd','frax','usds','usde','tusd','pyusd','fdusd','paxg','lusd','xusd','usdb','susd','crvusd','dola','mim','rai','gusd'])
STABLE_SYM_PREFIXES = ('usd', 'eur', 'gbp')
WRAPPED = set(['wbtc','weth','cbbtc','cbeth','reth','wrapped-bitcoin','wrapped-ethereum','lido-staked-ether'])
WRAPPED_SYMS = set(['wbtc','weth','steth','wsteth','reth','cbbtc','cbeth','weeth'])

def is_stable(c):
    if c['id'] in STABLE_IDS: return True
    sym = c['symbol'].lower()
    if sym in STABLE_SYMS: return True
    if any(sym.startswith(p) for p in STABLE_SYM_PREFIXES): return True
    if 'stablecoin' in c['name'].lower(): return True
    return False

def is_wrapped(c):
    return c['id'] in WRAPPED or c['symbol'].lower() in WRAPPED_SYMS

filtered = []
for c in markets:
    if is_stable(c): continue
    if is_wrapped(c): continue
    vol = c.get('total_volume') or 0
    if vol < 1000000: continue
    filtered.append(c)

print(f"After filter: {len(filtered)} coins")

def pct24(c): return c.get('price_change_percentage_24h_in_currency') or 0
def pct7d(c): return c.get('price_change_percentage_7d_in_currency') or 0
def pct1h(c): return c.get('price_change_percentage_1h_in_currency') or 0

winners = sorted(filtered, key=pct24, reverse=True)[:10]
losers = sorted(filtered, key=pct24)[:10]

trending_ids = set()
trending_syms_set = set()
for t in trending_coins[:7]:
    item = t.get('item', {})
    trending_ids.add(item.get('id',''))
    trending_syms_set.add(item.get('symbol','').lower())

def get_tags(c):
    tags = []
    p24 = pct24(c)
    p7d = pct7d(c)
    rank = c.get('market_cap_rank') or 999
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 1
    coin_id = c.get('id','')
    sym = c.get('symbol','').lower()
    is_trending = (coin_id in trending_ids or sym in trending_syms_set)
    if is_trending and p24 > 0: tags.append('[TRENDING+UP]')
    if is_trending and p24 < 0: tags.append('[TRENDING+DOWN]')
    if p24 > 15 and p7d > 25: tags.append('[BREAKOUT]')
    if p24 > 20 and p7d < 0: tags.append('[FADE]')
    if p24 < -10 and (vol/mcap) > 0.25: tags.append('[CAPITULATION]')
    if rank > 150 and p24 > 30: tags.append('[PUMP-RISK]')
    if (c.get('market_cap') or 0) < 50000000: tags.append('[MICROCAP]')
    if rank <= 20: tags.append('[MAJOR]')
    return tags[:2]

top100 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
n_green = sum(1 for c in top100 if pct24(c) > 0)
sorted50 = sorted(top100, key=lambda c: c.get('market_cap_rank') or 999)[:50]
p24vals = sorted([pct24(c) for c in sorted50])
median_p24 = p24vals[len(p24vals)//2] if p24vals else 0

print(f"PULSE_DATA: {n_green}/{len(top100)} green, median={median_p24:.2f}")

def fmt_price(p):
    if p is None: return 'N/A'
    if p >= 100: return "$" + "{:,.2f}".format(p)
    if p >= 1: return "$" + "{:.4f}".format(p)
    if p >= 0.01: return "$" + "{:.4f}".format(p)
    return "$" + "{:.6f}".format(p)

def fmt_abbr(v):
    if v is None: return 'N/A'
    if v >= 1e9: return "$" + "{:.1f}".format(v/1e9) + "B"
    if v >= 1e6: return "$" + "{:.0f}".format(v/1e6) + "M"
    return "$" + "{:.0f}".format(v/1e3) + "K"

output_lines = []
output_lines.append("===WINNERS===")
for i, c in enumerate(winners, 1):
    tags = get_tags(c)
    sym = c['symbol'].upper()
    name = c['name']
    price = fmt_price(c.get('current_price'))
    p24 = pct24(c)
    p7d = pct7d(c)
    p1h = pct1h(c)
    vol = fmt_abbr(c.get('total_volume'))
    rank = str(c.get('market_cap_rank','?'))
    tag_str = ' '.join(tags)
    output_lines.append(str(i) + "|" + sym + "|" + name + "|" + price + "|" + "{:.1f}".format(p24) + "|" + "{:.1f}".format(p7d) + "|" + "{:.1f}".format(p1h) + "|" + vol + "|" + rank + "|" + tag_str)

output_lines.append("===LOSERS===")
for i, c in enumerate(losers, 1):
    tags = get_tags(c)
    sym = c['symbol'].upper()
    name = c['name']
    price = fmt_price(c.get('current_price'))
    p24 = pct24(c)
    p7d = pct7d(c)
    p1h = pct1h(c)
    vol = fmt_abbr(c.get('total_volume'))
    rank = str(c.get('market_cap_rank','?'))
    tag_str = ' '.join(tags)
    output_lines.append(str(i) + "|" + sym + "|" + name + "|" + price + "|" + "{:.1f}".format(p24) + "|" + "{:.1f}".format(p7d) + "|" + "{:.1f}".format(p1h) + "|" + vol + "|" + rank + "|" + tag_str)

output_lines.append("===TRENDING===")
for i, t in enumerate(trending_coins[:7], 1):
    item = t.get('item', {})
    name = item.get('name','?')
    sym = item.get('symbol','?').upper()
    tr_rank = str(item.get('market_cap_rank','?'))
    data = item.get('data', {})
    price_str = str(data.get('price','?'))
    p24_raw = data.get('price_change_percentage_24h', {})
    if isinstance(p24_raw, dict):
        p24 = p24_raw.get('usd', None)
    else:
        p24 = p24_raw
    p24_str = "{:+.1f}%".format(p24) if p24 is not None else "N/A"
    coin_id = item.get('id','')
    sym_l = sym.lower()
    market_coin = next((c for c in filtered if c['id']==coin_id or c['symbol'].lower()==sym_l), None)
    extra_tag = ''
    if market_coin:
        p24_val = pct24(market_coin)
        if p24_val > 0: extra_tag = '[TRENDING+UP]'
        else: extra_tag = '[TRENDING+DOWN]'
        mc_rank = market_coin.get('market_cap_rank', 999)
        if mc_rank > 150 and p24_val > 30: extra_tag = extra_tag + ' [PUMP-RISK]'
    output_lines.append(str(i) + "|" + name + "|" + sym + "|" + tr_rank + "|" + price_str + "|" + p24_str + "|" + extra_tag)

print('\n'.join(output_lines))
