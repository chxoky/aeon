import json

with open('.markets.json') as f:
    coins = json.load(f)

stable_ids = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','ethena-usde','binance-usd','frax','usdt','staked-usde','usds','sky-dollar','usd0','usdb','crvusd','gho','ethena-staked-usde','usdt0','buidl'}

def is_stable(c):
    sym = (c.get('symbol') or '').upper()
    name = (c.get('name') or '').lower()
    cid = c.get('id') or ''
    if cid in stable_ids: return True
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

def g(c,k):
    v=c.get(k); return v if v is not None else 0
def d24(c): return g(c,'price_change_percentage_24h_in_currency')
def d7(c): return g(c,'price_change_percentage_7d_in_currency')
def d1(c): return g(c,'price_change_percentage_1h_in_currency')

winners = sorted(filtered, key=d24, reverse=True)[:10]
losers = sorted(filtered, key=d24)[:10]

with open('.trending.json') as f:
    tr = json.load(f)
trending = []
for item in tr.get('coins', [])[:7]:
    ci = item.get('item', {})
    d = ci.get('data', {})
    price = d.get('price') if isinstance(d.get('price'),(int,float)) else None
    ch = None
    pcp = d.get('price_change_percentage_24h')
    if isinstance(pcp, dict): ch = pcp.get('usd')
    trending.append({
        'name': ci.get('name'),
        'symbol': (ci.get('symbol') or '').upper(),
        'rank': ci.get('market_cap_rank'),
        'price': price,
        'ch24': ch,
    })

trending_syms = {t['symbol'] for t in trending if t['symbol']}
winner_syms = {(c.get('symbol') or '').upper() for c in winners}
loser_syms = {(c.get('symbol') or '').upper() for c in losers}

def tags(c):
    t=[]
    sym=(c.get('symbol') or '').upper()
    rank=c.get('market_cap_rank') or 9999
    mcap=c.get('market_cap') or 0
    vol=c.get('total_volume') or 0
    a24=d24(c); a7=d7(c)
    if sym in trending_syms and a24>0: t.append('TRENDING+UP')
    if sym in trending_syms and a24<0: t.append('TRENDING+DOWN')
    if a24>15 and a7>25: t.append('BREAKOUT')
    if a24>20 and a7<0: t.append('FADE')
    if a24<-10 and mcap>0 and (vol/mcap)>0.25: t.append('CAPITULATION')
    if rank>150 and a24>30: t.append('PUMP-RISK')
    if mcap<50_000_000: t.append('MICROCAP')
    if rank<=20: t.append('MAJOR')
    return t[:2]

def fmtprice(p):
    if p is None: return 'n/a'
    if p>=1000: return '$' + format(p, ',.0f')
    if p>=1: return '$' + format(p, ',.2f')
    if p>=0.01: return '$' + format(p, '.4f')
    return '$' + format(p, '.6f')

def fmtbig(v):
    if v is None: return 'n/a'
    if v>=1e9: return '$' + format(v/1e9, '.1f') + 'B'
    if v>=1e6: return '$' + format(v/1e6, '.0f') + 'M'
    if v>=1e3: return '$' + format(v/1e3, '.0f') + 'K'
    return '$' + format(v, '.0f')

def line(c):
    sym=(c.get('symbol') or '').upper()
    tg=tags(c)
    tgs=(' ['+', '.join(tg)+']') if tg else ''
    return sym+' ('+str(c.get('name'))+') — '+fmtprice(c.get('current_price'))+'  '+format(d24(c),'+.1f')+'% / 7d '+format(d7(c),'+.1f')+'% / 1h '+format(d1(c),'+.1f')+'%  •  '+fmtbig(c.get('total_volume'))+' / #'+str(c.get('market_cap_rank'))+tgs

print("=== WINNERS ===")
for c in winners: print(line(c))
print("\n=== LOSERS ===")
for c in losers: print(line(c))
print("\n=== TRENDING ===")
for t in trending:
    tg=[]
    if t['symbol'] in winner_syms: tg.append('TRENDING+UP')
    if t['symbol'] in loser_syms: tg.append('TRENDING+DOWN')
    tgs=(' ['+', '.join(tg)+']') if tg else ''
    ch = (format(t['ch24'],'+.1f')+'%') if t['ch24'] is not None else 'n/a'
    print(str(t['name'])+' ('+t['symbol']+') — #'+str(t['rank'])+', '+fmtprice(t['price'])+', 24h '+ch+tgs)

top100 = sorted(filtered, key=lambda c: c.get('market_cap_rank') or 9999)[:100]
green = sum(1 for c in top100 if d24(c)>0)
top50 = sorted(filtered, key=lambda c: c.get('market_cap_rank') or 9999)[:50]
meds = sorted(d24(c) for c in top50)
median = meds[len(meds)//2] if meds else 0
print("\n=== PULSE === green "+str(green)+"/"+str(len(top100))+", top50 median 24h "+format(median,'+.2f')+"%")
for c in coins:
    if c.get('id')=='bitcoin':
        print("BTC: "+fmtprice(c.get('current_price'))+" 24h "+format(d24(c),'+.1f')+"% 7d "+format(d7(c),'+.1f')+"%")
    if c.get('id')=='ethereum':
        print("ETH: "+fmtprice(c.get('current_price'))+" 24h "+format(d24(c),'+.1f')+"% 7d "+format(d7(c),'+.1f')+"%")
