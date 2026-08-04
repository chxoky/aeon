import json, sys

data = json.load(sys.stdin)
coins = data.get('coins', [])[:7]
for i, entry in enumerate(coins, 1):
    item = entry.get('item', {})
    d = item.get('data', {})
    name = item.get('name','')
    sym = item.get('symbol','')
    rank = item.get('market_cap_rank','?')
    coin_id = item.get('id','')
    price = d.get('price', 0)
    pct_map = d.get('price_change_percentage_24h', {})
    pct24 = pct_map.get('usd', 0) if isinstance(pct_map, dict) else 0
    if price >= 1:
        price_str = f'${price:,.4g}'
    elif price >= 0.01:
        price_str = f'${price:.4f}'
    else:
        price_str = f'${price:.6f}'
    print(f'{i}|{coin_id}|{name}|{sym}|{rank}|{price_str}|{pct24:+.1f}%')
