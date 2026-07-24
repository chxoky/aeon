import urllib.request, json, sys

def fetch(url):
    with urllib.request.urlopen(url, timeout=25) as r:
        return json.loads(r.read())

coins = fetch("https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d")

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','trueusd','usdd',
              'paypal-usd','fdusd','pax-gold','ethena-usde','usual-usd','bridged-usdc-polygon',
              'usd-plus','liquity-usd','frax','magic-internet-money'}

def is_stable(c):
    if c['id'] in STABLE_IDS: return True
    sym = c['symbol'].lower()
    name = c['name'].lower()
    if any(sym.startswith(p) for p in ('usd','eur','gbp')): return True
    if 'stablecoin' in name: return True
    return False

def is_wrapped(c):
    return c['id'] in {'wrapped-bitcoin','wrapped-ethereum','wrapped-steth','staked-ether',
                       'wrapped-eeth','wbtc','weth','steth','rocket-pool-eth','coinbase-wrapped-staked-eth'}

filtered = [c for c in coins if not is_stable(c) and not is_wrapped(c)
            and (c.get('total_volume') or 0) >= 1_000_000]

def p24(c): return c.get('price_change_percentage_24h_in_currency') or 0
def p7d(c): return c.get('price_change_percentage_7d_in_currency') or 0
def p1h(c): return c.get('price_change_percentage_1h_in_currency') or 0

sorted_coins = sorted(filtered, key=p24, reverse=True)
winners = sorted_coins[:10]
losers = list(reversed(sorted_coins[-10:]))

top100 = sorted(filtered, key=lambda c: c.get('market_cap') or 0, reverse=True)[:100]
green_count = sum(1 for c in top100 if p24(c) > 0)
top50 = top100[:50]
med50 = sorted([p24(c) for c in top50])[25]

trend_data = fetch("https://api.coingecko.com/api/v3/search/trending")
trend_coins = trend_data.get('coins', [])[:7]
trending_ids = {tc['item']['id'] for tc in trend_coins}

def fmt_vol(v):
    if v >= 1e9: return f"${v/1e9:.1f}B"
    if v >= 1e6: return f"${v/1e6:.0f}M"
    return f"${v:.0f}"

def fmt_price(p):
    if p >= 1000: return f"${p:,.0f}"
    if p >= 1: return f"${p:.4g}"
    if p >= 0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_pct(v):
    if v is None: return "n/a"
    sign = "+" if v >= 0 else ""
    return f"{sign}{v:.1f}%"

def get_tags(c):
    tags = []
    pc24 = p24(c)
    pc7d = p7d(c)
    rank = c.get('market_cap_rank') or 999
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 1
    cid = c['id']
    in_trend = cid in trending_ids

    if in_trend and pc24 > 0: tags.append('[TRENDING+UP]')
    elif in_trend and pc24 < 0: tags.append('[TRENDING+DOWN]')

    if pc24 > 15 and pc7d > 25: tags.append('[BREAKOUT]')
    elif pc24 > 20 and pc7d < 0: tags.append('[FADE]')

    if pc24 < -10 and vol / mcap > 0.25: tags.append('[CAPITULATION]')
    if rank > 150 and pc24 > 30: tags.append('[PUMP-RISK]')
    if mcap < 50_000_000: tags.append('[MICROCAP]')
    elif rank <= 20: tags.append('[MAJOR]')

    return ' '.join(tags[:2])

print(f"MARKET_PULSE:{green_count}/100 green, median top-50 {fmt_pct(med50)}")
print()
print("WINNERS:")
for i, c in enumerate(winners, 1):
    t = get_tags(c)
    print(f"{i}|{c['symbol'].upper()}|{c['name']}|{fmt_price(c['current_price'])}|{fmt_pct(p24(c))}|{fmt_pct(p7d(c))}|{fmt_pct(p1h(c))}|{fmt_vol(c['total_volume'])}|#{c['market_cap_rank']}|{t}")

print()
print("LOSERS:")
for i, c in enumerate(losers, 1):
    t = get_tags(c)
    print(f"{i}|{c['symbol'].upper()}|{c['name']}|{fmt_price(c['current_price'])}|{fmt_pct(p24(c))}|{fmt_pct(p7d(c))}|{fmt_pct(p1h(c))}|{fmt_vol(c['total_volume'])}|#{c['market_cap_rank']}|{t}")

print()
print("TRENDING:")
for i, tc in enumerate(trend_coins, 1):
    item = tc['item']
    data = item.get('data', {})
    pch = data.get('price_change_percentage_24h', {})
    pch_usd = pch.get('usd') if isinstance(pch, dict) else None
    price_raw = data.get('price', 0)
    try: price_str = fmt_price(float(price_raw))
    except: price_str = '?'
    rank = item.get('market_cap_rank') or 9999
    in_tr = item['id'] in trending_ids
    trend_tag = '[TRENDING+UP]' if (pch_usd or 0) > 0 else '[TRENDING+DOWN]' if (pch_usd or 0) < 0 else ''
    if rank > 150 and (pch_usd or 0) > 30: trend_tag += ' [PUMP-RISK]'
    print(f"{i}|{item['name']}|{item['symbol']}|#{rank}|{price_str}|{fmt_pct(pch_usd)}|{trend_tag.strip()}")
