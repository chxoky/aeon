import json

m = json.load(open('.tmp_markets.json'))
tr = json.load(open('.tmp_trending.json'))

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd',
              'pyusd','fdusd','paxg','ethena-usde','binance-usd','frax','usdb',
              'gho','crvusd','susd','lusd','usdx','usd1','ripple-usd','usds',
              'blackrock-usd-institutional-digital-liquidity-fund','ondo-us-dollar-yield',
              'global-dollar','falcon-finance-usdf','tether-gold'}

def is_stable(c):
    cid = c.get('id','')
    sym = (c.get('symbol') or '').upper()
    name = (c.get('name') or '').lower()
    if cid in STABLE_IDS: return True
    if sym.startswith('USD') or sym.startswith('EUR') or sym.startswith('GBP'): return True
    if 'stablecoin' in name or 'usd' in cid and 'yield' in cid: return True
    return False

WRAPPED = {'wbtc','weth','steth','wsteth','weeth','wbeth','reth','cbbtc','lbtc',
           'weeth','solvbtc','msol','jitosol','rseth','ezeth','binance-peg'}

rows = []
for c in m:
    if is_stable(c): continue
    sym = (c.get('symbol') or '').lower()
    cid = c.get('id','')
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    if sym in WRAPPED: continue
    rows.append(c)

def g(c,k):
    v=c.get(k)
    return v if v is not None else 0

# market pulse: top 100 by mcap after filters
top100 = rows[:100]
green = sum(1 for c in top100 if g(c,'price_change_percentage_24h')>0)
top50 = rows[:50]
med24 = sorted(g(c,'price_change_percentage_24h') for c in top50)
n=len(med24)
median50 = med24[n//2] if n%2 else (med24[n//2-1]+med24[n//2])/2
print("PULSE: green %d/%d  median_top50 %.2f  filtered_count=%d"%(green,len(top100),median50,len(rows)))

# BTC
for c in rows:
    if c['id']=='bitcoin':
        print("BTC price=%.0f 24h=%.2f 7d=%.2f"%(g(c,'current_price'),g(c,'price_change_percentage_24h'),g(c,'price_change_percentage_7d_in_currency')))

winners = sorted(rows, key=lambda c: g(c,'price_change_percentage_24h'), reverse=True)[:12]
losers = sorted(rows, key=lambda c: g(c,'price_change_percentage_24h'))[:12]

# trending
tcoins = []
for item in tr.get('coins',[]):
    it = item.get('item',{})
    d = it.get('data',{})
    tcoins.append({
        'name': it.get('name'),
        'symbol': (it.get('symbol') or '').upper(),
        'rank': it.get('market_cap_rank'),
        'price': (d.get('price') if isinstance(d.get('price'),(int,float)) else None),
        'pc24': (d.get('price_change_percentage_24h') or {}).get('usd') if isinstance(d.get('price_change_percentage_24h'),dict) else None,
    })

trending_syms = set(t['symbol'] for t in tcoins if t['symbol'])

def fmt(c,i):
    return "%d. %s (%s) rank#%s px=%.6g 24h=%.1f 7d=%.1f 1h=%.1f vol=%.3g mcap=%.3g" % (
        i, (c.get('symbol') or '').upper(), c.get('name'),
        c.get('market_cap_rank'), g(c,'current_price'),
        g(c,'price_change_percentage_24h'), g(c,'price_change_percentage_7d_in_currency'),
        g(c,'price_change_percentage_1h_in_currency'), g(c,'total_volume'), g(c,'market_cap'))

print("\n=== WINNERS ===")
for i,c in enumerate(winners,1): print(fmt(c,i), "TREND" if (c.get('symbol') or '').upper() in trending_syms else "")
print("\n=== LOSERS ===")
for i,c in enumerate(losers,1): print(fmt(c,i), "TREND" if (c.get('symbol') or '').upper() in trending_syms else "")
print("\n=== TRENDING ===")
for i,t in enumerate(tcoins[:8],1):
    print("%d. %s (%s) rank#%s px=%s 24h=%s"%(i,t['name'],t['symbol'],t['rank'],
          ("%.6g"%t['price']) if t['price'] else '?', ("%.1f"%t['pc24']) if t['pc24'] is not None else '?'))
EOF_MARK = None
