import json, sys, urllib.request

def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

data = fetch("https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d")

try:
    trending_data = fetch("https://api.coingecko.com/api/v3/search/trending")
    trending_coins = trending_data.get('coins', [])
except Exception as e:
    trending_coins = []
    print(f"TRENDING_UNAVAILABLE: {e}")

STABLE_IDS = {
    'tether','usd-coin','dai','first-digital-usd','ethena-usde','true-usd','usdd','paypal-usd',
    'fdusd','pax-gold','tether-gold','usds','usd1-wlfi','ripple-usd','global-dollar',
    'hashnote-usyc','blackrock-usd-institutional-digital-liquidity-fund','bfusd','falcon-finance',
    'ondo-us-dollar-yield','usual-usd','united-stables','gho','ylds','usdgo','eurc',
    'superstate-short-duration-us-government-securities-fund-ustb','eutbl',
    'janus-henderson-anemoy-treasury-fund','janus-henderson-anemoy-aaa-clo-fund',
    'spiko-amundi-overnight-swap-fund-eur','euro-coin','blockchain-capital','figure-heloc',
    'a7a5','ripple-usd','blackrock-usd-institutional-digital-liquidity-fund'
}
STABLE_SYMS = {
    'usdt','usdc','dai','usde','tusd','usdd','pyusd','fdusd','busd','gusd','frax','ust','usd1',
    'rlusd','usdg','usyc','buidl','bfusd','usdf','usd0','u','gho','ylds','usdgo','ustb','eutbl',
    'eursafo','eurc','usds','usdy','paxg','xaut','a7a5','figr_heloc','jaaa','jtrsy','bcap',
    'hash'
}
WRAPPED = {'wbtc','weth','steth','wsteth','cbbtc','sbtc'}

def is_excluded(c):
    sym = (c.get('symbol') or '').lower()
    cid = (c.get('id') or '').lower()
    name = (c.get('name') or '').lower()
    vol = c.get('total_volume') or 0
    if cid in STABLE_IDS or sym in STABLE_SYMS or sym in WRAPPED:
        return True
    if sym.startswith('usd') or sym.startswith('eur') or sym.startswith('gbp'):
        return True
    if 'stablecoin' in name:
        return True
    if vol < 1_000_000:
        return True
    # Also skip illiquid fund tokens (zero trading volume)
    if vol == 0:
        return True
    # Also skip coin with chinese characters in symbol
    if any(ord(ch) > 127 for ch in sym):
        return True
    return False

filtered = [c for c in data if not is_excluded(c)]

# Trending set
trending_ids = set()
for t in trending_coins:
    item = t.get('item', t)
    trending_ids.add(item.get('id',''))

# Compute tags
def get_tags(c):
    tags = []
    sym = (c.get('symbol') or '').upper()
    cid = (c.get('id') or '')
    rank = c.get('market_cap_rank') or 999
    ch24 = c.get('price_change_percentage_24h_in_currency') or 0
    ch7 = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mc = c.get('market_cap') or 0

    is_trending = cid in trending_ids

    if is_trending and ch24 > 0:
        tags.append('[TRENDING+UP]')
    elif is_trending and ch24 < 0:
        tags.append('[TRENDING+DOWN]')

    if ch24 > 15 and ch7 > 25:
        tags.append('[BREAKOUT]')
    elif ch24 > 20 and ch7 < 0:
        tags.append('[FADE]')

    if ch24 < -10 and mc > 0 and vol / mc > 0.25:
        tags.append('[CAPITULATION]')

    if rank > 150 and ch24 > 30:
        tags.append('[PUMP-RISK]')

    if mc > 0 and mc < 50_000_000:
        tags.append('[MICROCAP]')

    if rank <= 20:
        tags.append('[MAJOR]')

    return tags[:2]

# Sort winners / losers
sorted_up = sorted(filtered, key=lambda x: x.get('price_change_percentage_24h_in_currency') or 0, reverse=True)
sorted_down = sorted(filtered, key=lambda x: x.get('price_change_percentage_24h_in_currency') or 0)

def fmt_price(p):
    if p is None: return 'N/A'
    if p >= 1000: return f"${p:,.0f}"
    if p >= 1: return f"${p:.2f}"
    if p >= 0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_vol(v):
    if v >= 1e9: return f"${v/1e9:.1f}B"
    if v >= 1e6: return f"${v/1e6:.0f}M"
    return f"${v/1e3:.0f}K"

def fmt_mc(v):
    if v >= 1e9: return f"${v/1e9:.1f}B"
    if v >= 1e6: return f"${v/1e6:.0f}M"
    return f"${v/1e3:.0f}K"

winners = sorted_up[:10]
losers = sorted_down[:10]

# Market pulse: top filtered coins with rank <= 100
top_filtered = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
green_count = sum(1 for c in top_filtered if (c.get('price_change_percentage_24h_in_currency') or 0) > 0)
red_count = len(top_filtered) - green_count
top50_changes = sorted([c.get('price_change_percentage_24h_in_currency') or 0 for c in top_filtered[:50]])
median_chg = top50_changes[len(top50_changes)//2] if top50_changes else 0

print(f"TOTAL_DATASET:{len(data)}")
print(f"FILTERED:{len(filtered)}")
print(f"PULSE_GREEN:{green_count} PULSE_RED:{red_count} MEDIAN:{median_chg:.1f}")
print()
print("=== WINNERS ===")
for i, c in enumerate(winners, 1):
    sym = (c.get('symbol') or '').upper()
    name = c.get('name') or ''
    rank = c.get('market_cap_rank') or '?'
    price = fmt_price(c.get('current_price'))
    ch24 = c.get('price_change_percentage_24h_in_currency') or 0
    ch7 = c.get('price_change_percentage_7d_in_currency') or 0
    ch1 = c.get('price_change_percentage_1h_in_currency') or 0
    vol = fmt_vol(c.get('total_volume') or 0)
    mc = fmt_mc(c.get('market_cap') or 0)
    tags = ' '.join(get_tags(c))
    print(f"{i}. {sym} ({name}) — {price}  {ch24:+.1f}% / 7d {ch7:+.1f}% / 1h {ch1:+.1f}%  •  {vol} / #{rank}  {tags}")

print()
print("=== LOSERS ===")
for i, c in enumerate(losers, 1):
    sym = (c.get('symbol') or '').upper()
    name = c.get('name') or ''
    rank = c.get('market_cap_rank') or '?'
    price = fmt_price(c.get('current_price'))
    ch24 = c.get('price_change_percentage_24h_in_currency') or 0
    ch7 = c.get('price_change_percentage_7d_in_currency') or 0
    ch1 = c.get('price_change_percentage_1h_in_currency') or 0
    vol = fmt_vol(c.get('total_volume') or 0)
    mc = fmt_mc(c.get('market_cap') or 0)
    tags = ' '.join(get_tags(c))
    print(f"{i}. {sym} ({name}) — {price}  {ch24:+.1f}% / 7d {ch7:+.1f}% / 1h {ch1:+.1f}%  •  {vol} / #{rank}  {tags}")

print()
print("=== TRENDING (top 7) ===")
for i, t in enumerate(trending_coins[:7], 1):
    item = t.get('item', t)
    sym = (item.get('symbol') or '').upper()
    name = item.get('name') or ''
    rank = item.get('market_cap_rank') or '?'
    # price data from trending endpoint
    data_entry = item.get('data', {})
    price_str = data_entry.get('price', '')
    ch24_pct = data_entry.get('price_change_percentage_24h', {})
    if isinstance(ch24_pct, dict):
        ch24 = ch24_pct.get('usd', None)
    else:
        ch24 = ch24_pct
    ch24_str = f"{ch24:+.1f}%" if ch24 is not None else "N/A"
    # Try to match to markets data for richer info
    cid = item.get('id','')
    matched = next((c for c in data if c.get('id') == cid), None)
    if matched:
        price_str = fmt_price(matched.get('current_price'))
        mc_ch = matched.get('price_change_percentage_24h_in_currency') or 0
        ch24_str = f"{mc_ch:+.1f}%"
        rank = matched.get('market_cap_rank') or rank
    tags = ''
    if matched:
        tags = ' '.join(get_tags(matched))
    print(f"{i}. {name} ({sym}) — #{rank}, {price_str}, 24h {ch24_str}  {tags}")
