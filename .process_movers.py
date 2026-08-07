#!/usr/bin/env python3
import json, sys

STABLECOIN_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
                   'binance-usd','true-usd','frax','liquity-usd','dollar-on-chain','celo-dollar','gemini-dollar',
                   'stasis-eurs','tether-eurt','euro-coin','usd+','usdx-money','ethena-usde','usdb'}
WRAPPED_IDS = {'wrapped-bitcoin','wrapped-ethereum','wrapped-steth','staked-ether','wrapped-bnb',
                'rocket-pool-eth','coinbase-wrapped-staked-eth','mantle-staked-ether','kelp-dao-restaked-eth',
                'lido-staked-ether'}

with open('/home/runner/work/aeon/aeon/.cg_markets.json') as f:
    raw = json.load(f)

filtered = []
for c in raw:
    cid = c.get('id','').lower()
    sym = c.get('symbol','').lower()
    name = (c.get('name') or '').lower()
    vol = c.get('total_volume') or 0
    if cid in STABLECOIN_IDS: continue
    if cid in WRAPPED_IDS: continue
    if sym.startswith(('usd','eur','gbp')): continue
    if 'stablecoin' in name: continue
    if vol < 1_000_000: continue
    filtered.append(c)

def get_24h(c):
    v = c.get('price_change_percentage_24h_in_currency')
    if v is None: v = c.get('price_change_percentage_24h')
    return v or 0

def get_7d(c):
    return c.get('price_change_percentage_7d_in_currency') or 0

def get_1h(c):
    return c.get('price_change_percentage_1h_in_currency') or 0

by_24h = sorted(filtered, key=lambda c: get_24h(c), reverse=True)
winners = by_24h[:10]
losers = list(reversed(by_24h[-10:]))

top100 = filtered[:100]
green = sum(1 for c in top100 if get_24h(c) >= 0)
changes50 = sorted([get_24h(c) for c in filtered[:50]])
median_50 = changes50[25] if len(changes50) >= 50 else 0

output = {
    'total_filtered': len(filtered),
    'pulse': {'green_of_100': green, 'median_top50_24h': round(median_50, 1)},
    'winners': [],
    'losers': [],
    'winner_ids': [c['id'] for c in winners],
    'loser_ids': [c['id'] for c in losers]
}

def make_entry(c):
    return {
        'symbol': c['symbol'].upper(),
        'name': c['name'],
        'rank': c.get('market_cap_rank'),
        'price': c.get('current_price'),
        'p24h': round(get_24h(c), 1),
        'p7d': round(get_7d(c), 1),
        'p1h': round(get_1h(c), 1),
        'vol': c.get('total_volume'),
        'mcap': c.get('market_cap'),
        'id': c['id']
    }

output['winners'] = [make_entry(c) for c in winners]
output['losers'] = [make_entry(c) for c in losers]

with open('/home/runner/work/aeon/aeon/.cg_results.json', 'w') as f:
    json.dump(output, f)
print("Done")
