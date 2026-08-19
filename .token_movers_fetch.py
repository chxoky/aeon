import urllib.request, json, sys

# Fetch markets
url1 = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d"
url2 = "https://api.coingecko.com/api/v3/search/trending"

try:
    with urllib.request.urlopen(url1, timeout=30) as r:
        markets = json.loads(r.read())
    print(f"MARKETS_OK:{len(markets)}")
except Exception as e:
    print(f"MARKETS_FAIL:{e}")
    markets = []

try:
    with urllib.request.urlopen(url2, timeout=30) as r:
        trending_raw = json.loads(r.read())
    trending = trending_raw.get('coins', [])
    print(f"TRENDING_OK:{len(trending)}")
except Exception as e:
    print(f"TRENDING_FAIL:{e}")
    trending = []

# STABLECOINS to exclude
STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','true-usd','usdb','binance-usd','frax','husd','lusd','stasis-eurs','seur','gyen','busd','terrausd'}
STABLE_SYM_PREFIX = ('usd','eur','gbp')
STABLE_NAMES = ('stablecoin','dollar','euro')
WRAPPED = {'wbtc','weth','steth','cbbtc','weeth','wsteth','reth'}

def is_stable(c):
    if c['id'] in STABLE_IDS:
        return True
    sym = c['symbol'].lower()
    if sym.startswith(STABLE_SYM_PREFIX):
        return True
    if sym in WRAPPED:
        return True
    name = c['name'].lower()
    for s in STABLE_NAMES:
        if s in name:
            return True
    return False

# Filter
filtered = [c for c in markets if not is_stable(c) and (c.get('total_volume') or 0) >= 1_000_000]
print(f"FILTERED:{len(filtered)}")

def chg24(c):
    return c.get('price_change_percentage_24h') or 0

def chg7(c):
    return c.get('price_change_percentage_7d_in_currency') or 0

def chg1(c):
    return c.get('price_change_percentage_1h_in_currency') or 0

sorted_coins = sorted(filtered, key=chg24, reverse=True)
winners = sorted_coins[:10]
losers = list(reversed(sorted_coins[-10:]))

# Trending top 7
trend_coins = []
for t in trending[:7]:
    item = t.get('item', {})
    data = item.get('data', {})
    price_str = data.get('price', '')
    try:
        price = float(str(price_str).replace('$','').replace(',',''))
    except Exception:
        price = 0.0
    chg = data.get('price_change_percentage_24h', {})
    chg_24h = chg.get('usd', 0) if isinstance(chg, dict) else 0
    trend_coins.append({
        'name': item.get('name',''),
        'symbol': item.get('symbol',''),
        'rank': item.get('market_cap_rank') or '?',
        'price': price,
        'chg24': chg_24h,
        'id': item.get('id','')
    })

trend_ids = set()
for t in trending[:7]:
    trend_ids.add(t.get('item', {}).get('id',''))

def fmt_price(p):
    if p is None:
        return '?'
    if p >= 1:
        return f"${p:,.4g}"
    elif p >= 0.01:
        return f"${p:.4f}"
    else:
        return f"${p:.6f}"

def fmt_vol(v):
    if v is None:
        return '?'
    if v >= 1e9:
        return f"${v/1e9:.2f}B"
    elif v >= 1e6:
        return f"${v/1e6:.1f}M"
    else:
        return f"${v/1e3:.0f}K"

def fmt_pct(p):
    if p is None:
        return '?'
    sign = '+' if p >= 0 else ''
    return f"{sign}{p:.1f}%"

def get_tags(c):
    t = []
    in_trend = c['id'] in trend_ids
    c24 = chg24(c)
    c7 = chg7(c)
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 1
    rank = c.get('market_cap_rank') or 999

    if in_trend and c24 > 0:
        t.append('[TRENDING+UP]')
    elif in_trend and c24 < 0:
        t.append('[TRENDING+DOWN]')

    if c24 > 15 and c7 > 25:
        t.append('[BREAKOUT]')
    elif c24 > 20 and c7 < 0:
        t.append('[FADE]')

    if c24 < -10 and vol > 0 and mcap > 0 and vol/mcap > 0.25:
        t.append('[CAPITULATION]')

    if rank > 150 and c24 > 30:
        t.append('[PUMP-RISK]')

    if not t:
        if mcap < 50_000_000:
            t.append('[MICROCAP]')
        elif rank <= 20:
            t.append('[MAJOR]')

    return ' '.join(t[:2])

# Market pulse
top100 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
green_count = sum(1 for c in top100 if chg24(c) > 0)
pulse_total = len(top100)
top50 = sorted(top100, key=lambda c: c.get('market_cap_rank') or 999)[:50]
chg_vals = sorted([chg24(c) for c in top50])
median_chg = chg_vals[len(chg_vals)//2]

print(f"\n=== MARKET PULSE ===")
print(f"Top-100 non-stable green: {green_count}/{pulse_total}, median 24h (top-50): {median_chg:+.1f}%")

print(f"\n=== WINNERS ===")
for i, c in enumerate(winners, 1):
    tg = get_tags(c)
    print(f"{i}. {c['symbol'].upper()} ({c['name']}) -- {fmt_price(c['current_price'])}  {fmt_pct(chg24(c))} / 7d {fmt_pct(chg7(c))} / 1h {fmt_pct(chg1(c))}  //  {fmt_vol(c.get('total_volume'))} / #{c.get('market_cap_rank','?')}  {tg}")

print(f"\n=== LOSERS ===")
for i, c in enumerate(losers, 1):
    tg = get_tags(c)
    print(f"{i}. {c['symbol'].upper()} ({c['name']}) -- {fmt_price(c['current_price'])}  {fmt_pct(chg24(c))} / 7d {fmt_pct(chg7(c))} / 1h {fmt_pct(chg1(c))}  //  {fmt_vol(c.get('total_volume'))} / #{c.get('market_cap_rank','?')}  {tg}")

print(f"\n=== TRENDING ===")
for i, t in enumerate(trend_coins, 1):
    print(f"{i}. {t['name']} ({t['symbol'].upper()}) -- #{t['rank']}, {fmt_price(t['price'])}, 24h {fmt_pct(t['chg24'])}")

print(f"\n=== NOTABLE CANDIDATES ===")
seen_notable = set()
all_items = winners + losers
for c in all_items:
    tg = get_tags(c)
    notable_tags = ['[TRENDING+UP]','[BREAKOUT]','[CAPITULATION]','[PUMP-RISK]','[TRENDING+DOWN]','[FADE]']
    if any(x in tg for x in notable_tags) and c['id'] not in seen_notable:
        seen_notable.add(c['id'])
        print(f"* {c['symbol'].upper()}: {tg} -- 24h {fmt_pct(chg24(c))}, 7d {fmt_pct(chg7(c))}, vol {fmt_vol(c.get('total_volume'))}, rank #{c.get('market_cap_rank','?')}")
