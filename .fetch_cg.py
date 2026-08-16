#!/usr/bin/env python3
import urllib.request, json, os, sys

STABLECOINS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
               'binance-usd','gemini-dollar','frax','true-usd','celo-dollar','nusd','origin-dollar',
               'usd-balance','bridged-usd-coin','optimism-bridged-usdc-optimism','usdk','husd','susd',
               'stasis-eurs','terrausd','magic-internet-money','sperax','float-protocol-float','beans',
               'liquity-usd','reserve','vai','busd','cashio-dollar','dola-borrowing-right'}
STABLE_SYMBOLS = {'USDT','USDC','BUSD','DAI','TUSD','USDP','USDN','UST','USDD','FRAX','LUSD','SUSD',
                  'GUSD','HUSD','MUSD','RSV','EUROC','EURS','AGEUR','SEUR','EURC','XSGD','CADC'}

url = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d"
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as r:
        coins = json.loads(r.read())
    print(f"MARKETS_OK:{len(coins)}", flush=True)
except Exception as e:
    print(f"MARKETS_ERR:{e}", flush=True)
    sys.exit(1)

def is_stable(c):
    if c['id'] in STABLECOINS: return True
    sym = c['symbol'].upper()
    if sym in STABLE_SYMBOLS: return True
    if sym.startswith(('USD','EUR','GBP')): return True
    name = c['name'].lower()
    if 'stablecoin' in name or 'usd' == name[:3]: return True
    return False

def is_wrapped(c):
    return c['id'] in ('wrapped-bitcoin','wrapped-ether','staked-ether','wrapped-steth',
                        'weth','wbtc','wbnb','wrapped-eeth','wrapped-staked-ether')

filtered = [c for c in coins if not is_stable(c) and not is_wrapped(c) and (c.get('total_volume') or 0) >= 1_000_000]
print(f"FILTERED:{len(filtered)}", flush=True)

# Sort by 24h change
def pct24(c): return c.get('price_change_percentage_24h_in_currency') or 0.0

sorted_desc = sorted(filtered, key=pct24, reverse=True)

# Top 100 for market pulse (by original market cap rank)
top100 = sorted([c for c in filtered if (c.get('market_cap_rank') or 999) <= 110],
                key=lambda x: x.get('market_cap_rank') or 999)[:100]
pos = sum(1 for c in top100 if pct24(c) > 0)
neg = sum(1 for c in top100 if pct24(c) < 0)
pcts_top50 = sorted([pct24(c) for c in top100[:50]])
mid = len(pcts_top50)//2
median50 = (pcts_top50[mid] + pcts_top50[mid-1])/2 if len(pcts_top50) >= 2 else (pcts_top50[mid] if pcts_top50 else 0)
print(f"PULSE:top100_pos={pos},neg={neg},median50={median50:.2f}", flush=True)

# Top 10 winners
print("=== TOP 10 WINNERS ===")
for c in sorted_desc[:10]:
    r = c.get('market_cap_rank') or 0
    sym = c['symbol'].upper()
    name = c['name']
    price = c.get('current_price') or 0
    p24 = pct24(c)
    p7 = c.get('price_change_percentage_7d_in_currency') or 0.0
    p1 = c.get('price_change_percentage_1h_in_currency') or 0.0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    print(f"#{r}|{sym}|{name}|${price}|{p24:.1f}%|{p7:.1f}%|{p1:.1f}%|${vol:,.0f}|${mcap:,.0f}")

# Top 10 losers
print("=== TOP 10 LOSERS ===")
for c in sorted_desc[-10:][::-1]:
    r = c.get('market_cap_rank') or 0
    sym = c['symbol'].upper()
    name = c['name']
    price = c.get('current_price') or 0
    p24 = pct24(c)
    p7 = c.get('price_change_percentage_7d_in_currency') or 0.0
    p1 = c.get('price_change_percentage_1h_in_currency') or 0.0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    print(f"#{r}|{sym}|{name}|${price}|{p24:.1f}%|{p7:.1f}%|{p1:.1f}%|${vol:,.0f}|${mcap:,.0f}")
