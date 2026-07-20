import json, statistics

with open('.movers-cache/markets.json') as f:
    coins = json.load(f)
with open('.movers-cache/trending.json') as f:
    trending = json.load(f)

print("total coins:", len(coins))

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','ethena-usde','tusd','usdd','pyusd','fdusd','paxg','binance-usd','usds','ripple-usd','usdt0','ondo-us-dollar-yield','ethena-staked-usde'}

def is_stable(c):
    cid = (c.get('id') or '').lower()
    sym = (c.get('symbol') or '').upper()
    name = (c.get('name') or '').lower()
    if cid in STABLE_IDS: return True
    if sym.startswith('USD') or sym.startswith('EUR') or sym.startswith('GBP'): return True
    if 'stablecoin' in name: return True
    return False

filtered = []
for c in coins:
    if is_stable(c): continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    if c.get('price_change_percentage_24h_in_currency') is None: continue
    filtered.append(c)

print("after filter:", len(filtered))

byd = lambda c: c.get('price_change_percentage_24h_in_currency') or 0
winners = sorted(filtered, key=byd, reverse=True)[:10]
losers = sorted(filtered, key=byd)[:10]

def row(c):
    d7 = c.get('price_change_percentage_7d_in_currency') or 0
    h1 = c.get('price_change_percentage_1h_in_currency') or 0
    mcap = c.get('market_cap') or 0
    vol = c.get('total_volume') or 0
    print("%-7s %-22s #%-4s $%s | 24h %6.1f 7d %6.1f 1h %5.1f | vol %6.1fM mcap %8.0fM volmcap %.2f" % (
        c['symbol'].upper(), c['name'][:22], c.get('market_cap_rank'), c.get('current_price'),
        byd(c), d7, h1, vol/1e6, mcap/1e6, (vol/mcap if mcap else 0)))

print("\n=== WINNERS ===")
for c in winners: row(c)
print("\n=== LOSERS ===")
for c in losers: row(c)

top100 = filtered[:100]
green = sum(1 for c in top100 if byd(c) > 0)
med50 = statistics.median([byd(c) for c in filtered[:50]])
med100 = statistics.median([byd(c) for c in top100])
print("\n=== PULSE ===")
print("top100 green: %d/%d  median50: %.2f%%  median100: %.2f%%" % (green, len(top100), med50, med100))

print("\n=== MAJORS ===")
for c in filtered[:12]:
    print("  %-6s 24h %6.1f%% 7d %6.1f%%" % (c['symbol'].upper(), byd(c), c.get('price_change_percentage_7d_in_currency') or 0))

trend_syms = set()
print("\n=== TRENDING ===")
for item in trending.get('coins', [])[:10]:
    ci = item['item']
    data = ci.get('data', {})
    ch = None
    if data.get('price_change_percentage_24h'):
        ch = data['price_change_percentage_24h'].get('usd')
    trend_syms.add(ci.get('symbol','').upper())
    print("  %-8s %-22s rank #%s  price $%s  24h %s" % (
        ci.get('symbol','').upper(), ci.get('name','')[:22], ci.get('market_cap_rank'),
        data.get('price'), ("%.1f"%ch) if ch is not None else "n/a"))

win_syms = set(c['symbol'].upper() for c in winners)
lose_syms = set(c['symbol'].upper() for c in losers)
print("\nTrend∩Winners:", trend_syms & win_syms)
print("Trend∩Losers:", trend_syms & lose_syms)
