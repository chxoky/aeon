import urllib.request
import json
import sys

EXCLUDE_IDS = {
    'tether','usd-coin','dai','first-digital-usd','ethena-usde','true-usd','usdd','paypal-usd','fdusd',
    'pax-gold','wrapped-bitcoin','wrapped-ether','staked-ether','rocket-pool-eth','coinbase-wrapped-btc',
    'mantle-staked-ether','binance-peg-weth','lido-staked-matic','bridged-usdc-polygon',
    'binance-bridged-usdc-bnb-smart-chain','binance-bridged-usdt-bnb-smart-chain','wrapped-steth',
    'usdb','frax','frax-ether','usual-usd','tbtc','threshold-bitcoin','binance-peg-usd',
    'terrausd','neutrino','husd','bean','liquity-usd','gemini-dollar',
}
EXCLUDE_SYMBOL_PREFIX = ('usd','eur','gbp','jpy','aud','cad')

def is_excluded(c):
    if c['id'] in EXCLUDE_IDS:
        return True
    sym = c['symbol'].lower()
    if any(sym.startswith(p) for p in EXCLUDE_SYMBOL_PREFIX):
        return True
    name_lower = c['name'].lower()
    for w in ('stablecoin', 'pegged', 'bridged usd'):
        if w in name_lower:
            return True
    if (c.get('total_volume') or 0) < 1_000_000:
        return True
    return False

def fmt_price(p):
    if p is None: return 'N/A'
    if p >= 10000: return f"${p:,.0f}"
    if p >= 1000: return f"${p:,.1f}"
    if p >= 1: return f"${p:.4g}"
    if p >= 0.001: return f"${p:.5f}"
    return f"${p:.6f}"

def fmt_vol(v):
    if v is None: return 'N/A'
    if v >= 1e9: return f"${v/1e9:.1f}B"
    if v >= 1e6: return f"${v/1e6:.0f}M"
    return f"${v:,.0f}"

def compute_tags(c, trending_ids):
    t = []
    ch24 = c.get('price_change_percentage_24h') or 0
    ch7 = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 999
    vol_mcap_ratio = vol / mcap if mcap > 0 else 0
    in_trending = c['id'] in trending_ids

    if in_trending and ch24 > 0:
        t.append('[TRENDING+UP]')
    elif in_trending and ch24 < 0:
        t.append('[TRENDING+DOWN]')

    if ch24 > 15 and ch7 > 25:
        t.append('[BREAKOUT]')
    elif ch24 > 20 and ch7 < 0:
        t.append('[FADE]')

    if ch24 < -10 and vol_mcap_ratio > 0.25:
        t.append('[CAPITULATION]')

    if rank > 150 and ch24 > 30:
        t.append('[PUMP-RISK]')

    if mcap > 0 and mcap < 50_000_000:
        t.append('[MICROCAP]')

    if rank <= 20:
        t.append('[MAJOR]')

    return t[:2]

# Fetch markets
url_markets = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d"
url_trending = "https://api.coingecko.com/api/v3/search/trending"

try:
    with urllib.request.urlopen(url_markets, timeout=20) as r:
        coins = json.loads(r.read().decode())
    print(f"MARKETS_OK:{len(coins)}", file=sys.stderr)
except Exception as e:
    print(f"MARKETS_ERR:{e}", file=sys.stderr)
    sys.exit(1)

try:
    with urllib.request.urlopen(url_trending, timeout=20) as r:
        trend_data = json.loads(r.read().decode())
    trend_coins = trend_data.get('coins', [])
    trending_ids = set(tc['item']['id'] for tc in trend_coins)
    print(f"TRENDING_OK:{len(trend_coins)}", file=sys.stderr)
except Exception as e:
    print(f"TRENDING_ERR:{e}", file=sys.stderr)
    trend_coins = []
    trending_ids = set()

# Filter
filtered = [c for c in coins if not is_excluded(c)]

# Sort
by_24h = sorted(filtered, key=lambda c: c.get('price_change_percentage_24h') or 0)
losers = by_24h[:10]
winners = list(reversed(by_24h[-10:]))

# Market pulse
top100 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
positive = sum(1 for c in top100 if (c.get('price_change_percentage_24h') or 0) > 0)
changes_top50 = sorted([(c.get('price_change_percentage_24h') or 0) for c in top100[:50]])
median = changes_top50[len(changes_top50)//2] if changes_top50 else 0

# Output JSON for easy parsing
output = {
    "pulse": {"positive_top100": positive, "total_top100": len(top100), "median_top50_24h": round(median, 2)},
    "winners": [],
    "losers": [],
    "trending": [],
}

for c in winners:
    t = compute_tags(c, trending_ids)
    output["winners"].append({
        "symbol": c['symbol'].upper(),
        "name": c['name'],
        "price": fmt_price(c.get('current_price')),
        "ch24": round(c.get('price_change_percentage_24h') or 0, 1),
        "ch7": round(c.get('price_change_percentage_7d_in_currency') or 0, 1),
        "ch1": round(c.get('price_change_percentage_1h_in_currency') or 0, 1),
        "vol": fmt_vol(c.get('total_volume')),
        "rank": c.get('market_cap_rank', '?'),
        "tags": ' '.join(t),
        "id": c['id'],
    })

for c in losers:
    t = compute_tags(c, trending_ids)
    output["losers"].append({
        "symbol": c['symbol'].upper(),
        "name": c['name'],
        "price": fmt_price(c.get('current_price')),
        "ch24": round(c.get('price_change_percentage_24h') or 0, 1),
        "ch7": round(c.get('price_change_percentage_7d_in_currency') or 0, 1),
        "ch1": round(c.get('price_change_percentage_1h_in_currency') or 0, 1),
        "vol": fmt_vol(c.get('total_volume')),
        "rank": c.get('market_cap_rank', '?'),
        "tags": ' '.join(t),
        "id": c['id'],
    })

for tc in trend_coins[:7]:
    item = tc['item']
    data = tc.get('data', {})
    pch = data.get('price_change_percentage_24h', {})
    ch24 = pch.get('usd', 0) if isinstance(pch, dict) else 0
    output["trending"].append({
        "symbol": item.get('symbol', '').upper(),
        "name": item.get('name', ''),
        "rank": item.get('market_cap_rank', '?'),
        "price": fmt_price(data.get('price')),
        "ch24": round(ch24, 1),
        "id": item.get('id', ''),
        "tags": '[TRENDING+UP]' if ch24 > 0 else '[TRENDING+DOWN]' if ch24 < 0 else '',
    })

print(json.dumps(output))
