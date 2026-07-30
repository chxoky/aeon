import json

with open('/home/runner/.claude/projects/-home-runner-work-aeon-aeon/36d9189e-aeae-401a-a9dd-ea13f7b5c27f/tool-results/b5qtcvxho.txt') as f:
    data = json.load(f)

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','usds','rlusd','global-dollar','hashnote-usyc','ondo-us-dollar-yield','ripple-usd','blackrock-usd-institutional-digital-liquidity-fund','falcon-finance','bfusd','usd1-wlfi','tether-gold','ethena-usde'}
STABLE_SYMS = {'usdt','usdc','dai','busd','tusd','usdp','frax','lusd','gusd','susd','usdd','pyusd','fdusd','rlusd','usdg','usyc','usdy','buidl','usdf','bfusd','usd1','xaut','paxg'}
WRAPPED = {'wbtc','weth','steth','cbbtc','weeth'}

filtered = []
for c in data:
    sid = c['id']
    sym = c['symbol'].lower()
    name = c['name'].lower()
    vol = c.get('total_volume') or 0
    if sid in STABLE_IDS: continue
    if sym in STABLE_SYMS: continue
    if sym in WRAPPED: continue
    if 'stablecoin' in name: continue
    if sym.startswith('usd') or sym.startswith('eur') or sym.startswith('gbp'): continue
    if 'figure heloc' in name: continue
    if vol < 1_000_000: continue
    filtered.append(c)

winners = sorted(filtered, key=lambda c: c.get('price_change_percentage_24h_in_currency') or 0, reverse=True)[:10]
losers = sorted(filtered, key=lambda c: c.get('price_change_percentage_24h_in_currency') or 0)[:10]

print('=== TOP 10 WINNERS ===')
for c in winners:
    sym = c['symbol'].upper()
    name = c['name']
    rank = c['market_cap_rank']
    price = c['current_price']
    c24 = c.get('price_change_percentage_24h_in_currency') or 0
    c7d = c.get('price_change_percentage_7d_in_currency') or 0
    c1h = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    print(f'  {sym} ({name}) rank={rank} price={price} 24h={c24:.1f}% 7d={c7d:.1f}% 1h={c1h:.1f}% vol={vol/1e6:.1f}M mcap={mcap/1e9:.2f}B')

print()
print('=== TOP 10 LOSERS ===')
for c in losers:
    sym = c['symbol'].upper()
    name = c['name']
    rank = c['market_cap_rank']
    price = c['current_price']
    c24 = c.get('price_change_percentage_24h_in_currency') or 0
    c7d = c.get('price_change_percentage_7d_in_currency') or 0
    c1h = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    print(f'  {sym} ({name}) rank={rank} price={price} 24h={c24:.1f}% 7d={c7d:.1f}% 1h={c1h:.1f}% vol={vol/1e6:.1f}M mcap={mcap/1e9:.2f}B')

print()
print('=== MARKET PULSE ===')
top100 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
green = sum(1 for c in top100 if (c.get('price_change_percentage_24h_in_currency') or 0) > 0)
changes = sorted([c.get('price_change_percentage_24h_in_currency') or 0 for c in top100])
mid = len(changes)//2
median = changes[mid]
top50 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 50]
changes50 = sorted([c.get('price_change_percentage_24h_in_currency') or 0 for c in top50])
median50 = changes50[len(changes50)//2]
print(f'Top 100 filtered count: {len(top100)}, green: {green}, median 24h: {median:.1f}%')
print(f'Top 50 filtered count: {len(top50)}, median 24h: {median50:.1f}%')
print(f'Total filtered coins: {len(filtered)}')
