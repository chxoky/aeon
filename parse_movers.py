import json, sys

with open('/home/runner/.claude/projects/-home-runner-work-aeon-aeon/843c940b-08b1-4108-9e7d-5fcefdbf121a/tool-results/btr4vc3gn.txt') as f:
    data = json.load(f)

stablecoins = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','ethena-usde','usds','ripple-usd','hashnote-usyc','global-dollar','usd1-wlfi','tether-gold','blackrock-usd-institutional-digital-liquidity-fund','ondo-us-dollar-yield','paypal-usd'}
stable_symbols = {'USDT','USDC','DAI','TUSD','FDUSD','USDE','PYUSD','USD1','USDS','USDY','RLUSD','USDG','BUIDL','USYC'}

filtered = []
for c in data:
    if c['id'] in stablecoins:
        continue
    sym = (c.get('symbol') or '').upper()
    if sym.startswith('USD') or sym.startswith('EUR') or sym.startswith('GBP'):
        continue
    if sym in stable_symbols:
        continue
    if 'stablecoin' in (c.get('name') or '').lower():
        continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000:
        continue
    if c.get('price_change_percentage_24h') is None:
        continue
    filtered.append(c)

by_24h = sorted(filtered, key=lambda x: x['price_change_percentage_24h'], reverse=True)

print('=== TOP 15 WINNERS ===')
for c in by_24h[:15]:
    ch7 = c.get('price_change_percentage_7d_in_currency') or 0
    ch1 = c.get('price_change_percentage_1h_in_currency') or 0
    print(f"{c['symbol'].upper()} ({c['name']}) | rank #{c['market_cap_rank']} | 24h {c['price_change_percentage_24h']:+.1f}% | 7d {ch7:+.1f}% | 1h {ch1:+.1f}% | vol ${c['total_volume']/1e6:.1f}M | mcap ${c['market_cap']/1e6:.0f}M | price ${c['current_price']}")

print()
print('=== TOP 15 LOSERS ===')
for c in by_24h[-15:]:
    ch7 = c.get('price_change_percentage_7d_in_currency') or 0
    ch1 = c.get('price_change_percentage_1h_in_currency') or 0
    print(f"{c['symbol'].upper()} ({c['name']}) | rank #{c['market_cap_rank']} | 24h {c['price_change_percentage_24h']:+.1f}% | 7d {ch7:+.1f}% | 1h {ch1:+.1f}% | vol ${c['total_volume']/1e6:.1f}M | mcap ${c['market_cap']/1e6:.0f}M | price ${c['current_price']}")

print()
top100 = [c for c in filtered if c.get('market_cap_rank') and c['market_cap_rank'] <= 100]
green = sum(1 for c in top100 if c['price_change_percentage_24h'] > 0)
changes = sorted([c['price_change_percentage_24h'] for c in top100])
median = changes[len(changes)//2]
print(f'=== MARKET PULSE ===')
print(f'Top 100 (filtered): {len(top100)} coins, {green} green ({green/len(top100)*100:.0f}%)')
print(f'Median 24h change: {median:+.1f}%')

top50 = [c for c in filtered if c.get('market_cap_rank') and c['market_cap_rank'] <= 50]
ch50 = sorted([c['price_change_percentage_24h'] for c in top50])
median50 = ch50[len(ch50)//2]
print(f'Top 50 median 24h: {median50:+.1f}%')
