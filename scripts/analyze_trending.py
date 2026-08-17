import json, sys

data = json.load(sys.stdin)
coins = data.get('coins', [])

print(f"Trending ({len(coins)}):")
for c in coins[:10]:
    item = c.get('item', {})
    name = item.get('name', '?')
    sym = (item.get('symbol') or '?').upper()
    rank = item.get('market_cap_rank', '?')
    price_str = item.get('data', {}).get('price', '?')
    pct24 = item.get('data', {}).get('price_change_percentage_24h', {})
    if isinstance(pct24, dict):
        pct24 = pct24.get('usd', '?')
    if pct24 != '?':
        pct24 = f"{float(pct24):.1f}%"
    print(f"  {sym}|{name}|rank={rank}|{price_str}|24h={pct24}")
