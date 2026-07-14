import json

m = json.load(open('.markets.json'))
tr = json.load(open('.trending.json'))

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','ethena-usde','tusd','true-usd',
              'usdd','pyusd','paypal-usd','fdusd','paxos-standard','paxg','pax-gold','usds','sky-dollar',
              'binance-usd','usdc','frax','lusd','gho','crvusd','usd0','usdx','susds','blackrock-usd',
              'ondo-us-dollar-yield','buidl','usdt0'}

def is_stable(c):
    sid = c.get('id','').lower()
    sym = c.get('symbol','').upper()
    name = c.get('name','').lower()
    if sid in STABLE_IDS: return True
    if sym.startswith('USD') or sym.startswith('EUR') or sym.startswith('GBP'): return True
    if 'stablecoin' in name or 'usd' in sym.lower() and c.get('current_price') and 0.98 < c['current_price'] < 1.02 and abs(c.get('price_change_percentage_24h_in_currency') or 0) < 1: return True
    return False

def g(c,k):
    v=c.get(k)
    return v if v is not None else 0

filtered=[]
for c in m:
    if is_stable(c): continue
    if (c.get('total_volume') or 0) < 1_000_000: continue
    filtered.append(c)

# drop wrapped dupes if they'd dominate - keep note, but keep for now (rare in movers)
WRAPPED={'wbtc','weth','steth','wsteth','weeth','reth','wbeth','cbbtc','lbtc','solvbtc','msol','jitosol','beth','rseth','ezeth','weeth'}

def d24(c): return c.get('price_change_percentage_24h_in_currency')

valid=[c for c in filtered if d24(c) is not None]
winners=sorted(valid,key=lambda c:d24(c),reverse=True)[:15]
losers=sorted(valid,key=lambda c:d24(c))[:15]

# trending
trending=[]
for item in tr.get('coins',[])[:10]:
    it=item['item']
    d=it.get('data',{})
    trending.append({
        'name':it.get('name'),'symbol':(it.get('symbol') or '').upper(),
        'rank':it.get('market_cap_rank'),
        'price':d.get('price'),
        'ch24': (d.get('price_change_percentage_24h') or {}).get('usd')
    })
trending_syms={t['symbol'] for t in trending}

def fmt_price(p):
    if p is None: return 'n/a'
    if p>=1000: return f"${p:,.0f}"
    if p>=1: return f"${p:,.2f}"
    if p>=0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_big(v):
    if v is None: return 'n/a'
    if v>=1e9: return f"${v/1e9:.1f}B"
    if v>=1e6: return f"${v/1e6:.0f}M"
    if v>=1e3: return f"${v/1e3:.0f}K"
    return f"${v:.0f}"

def tags(c, in_winner):
    t=[]
    d24v=d24(c) or 0
    d7=c.get('price_change_percentage_7d_in_currency') or 0
    rank=c.get('market_cap_rank') or 9999
    mc=c.get('market_cap') or 0
    vol=c.get('total_volume') or 0
    sym=c.get('symbol','').upper()
    volmc = vol/mc if mc else 0
    if sym in trending_syms and in_winner: t.append('TRENDING+UP')
    if sym in trending_syms and not in_winner: t.append('TRENDING+DOWN')
    if d24v>15 and d7>25: t.append('BREAKOUT')
    if d24v>20 and d7<0: t.append('FADE')
    if d24v<-10 and volmc>0.25: t.append('CAPITULATION')
    if rank>150 and d24v>30: t.append('PUMP-RISK')
    if mc<50_000_000: t.append('MICROCAP')
    if rank<=20: t.append('MAJOR')
    # priority: always keep PUMP-RISK; cap 2
    if 'PUMP-RISK' in t:
        rest=[x for x in t if x!='PUMP-RISK']
        t=['PUMP-RISK']+rest
    return t[:2]

def line(c, in_winner):
    sym=c.get('symbol','').upper()
    name=c.get('name')
    d24v=d24(c) or 0
    d7=c.get('price_change_percentage_7d_in_currency')
    d1=c.get('price_change_percentage_1h_in_currency')
    d7s=f"{d7:+.0f}%" if d7 is not None else "n/a"
    d1s=f"{d1:+.1f}%" if d1 is not None else "n/a"
    tg=tags(c,in_winner)
    tgs=f"  [{', '.join(tg)}]" if tg else ""
    return f"{sym} ({name}) — {fmt_price(c.get('current_price'))}  {d24v:+.1f}% / 7d {d7s} / 1h {d1s}  •  {fmt_big(c.get('total_volume'))} / #{c.get('market_cap_rank')}{tgs}"

print("=== WINNERS ===")
for i,c in enumerate(winners[:10],1):
    print(i, line(c,True))
print("\n=== LOSERS ===")
for i,c in enumerate(losers[:10],1):
    print(i, line(c,False))
print("\n=== TRENDING ===")
for i,t in enumerate(trending[:7],1):
    tg=[]
    if t['symbol'] in {c['symbol'].upper() for c in winners[:10]}: tg.append('TRENDING+UP')
    if t['symbol'] in {c['symbol'].upper() for c in losers[:10]}: tg.append('TRENDING+DOWN')
    ch=t['ch24']
    chs=f"{ch:+.1f}%" if ch is not None else "n/a"
    tgs=f"  [{', '.join(tg)}]" if tg else ""
    print(i, f"{t['name']} ({t['symbol']}) — #{t['rank']}, {fmt_price(t['price'])}, 24h {chs}{tgs}")

# market pulse
top100=valid[:100]
pos=sum(1 for c in top100 if (d24(c) or 0)>0)
import statistics
top50=valid[:50]
med=statistics.median([d24(c) or 0 for c in top50])
print(f"\n=== PULSE ===")
print(f"top100 green: {pos}/{len(top100)}, top50 median 24h: {med:+.2f}%")
btc=next((c for c in m if c['id']=='bitcoin'),None)
eth=next((c for c in m if c['id']=='ethereum'),None)
print(f"BTC {fmt_price(btc['current_price'])} {d24(btc):+.1f}%/24h  ETH {fmt_price(eth['current_price'])} {d24(eth):+.1f}%/24h")
PY_END=1
