import json

mk = json.load(open('.tm_markets.json'))
tr = json.load(open('.tm_trending.json'))

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','ethena-usde',
              'tusd','true-usd','usdd','pyusd','paypal-usd','fdusd','paxg','pax-gold',
              'binance-usd','frax','usdc','gemini-dollar','blackrock-usd-institutional-digital-liquidity-fund',
              'ondo-us-dollar-yield','usds','sky-dollar','ripple-usd','rlusd'}

def is_stable(c):
    cid = (c.get('id') or '').lower()
    sym = (c.get('symbol') or '').upper()
    name = (c.get('name') or '').lower()
    if cid in STABLE_IDS: return True
    if sym.startswith('USD') or sym.startswith('EUR') or sym.startswith('GBP'): return True
    if 'stablecoin' in name or 'usd' in cid and 'yield' in cid: return True
    return False

def num(x):
    return x if isinstance(x,(int,float)) else None

filtered=[]
for c in mk:
    if is_stable(c): continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    if c.get('price_change_percentage_24h') is None: continue
    filtered.append(c)

# dedup wrapped/staked dupes by keeping first representative for known pairs
WRAP = {'wbtc':'btc','weth':'eth','steth':'eth','wsteth':'eth','wbeth':'eth',
        'reth':'eth','cbbtc':'btc','lbtc':'btc','weeth':'eth','beth':'eth','wbnb':'bnb',
        'jupsol':'sol','jitosol':'sol','msol':'sol','bsc-usd':'usd'}
seen_underlying=set()
dd=[]
for c in sorted(filtered, key=lambda x: x.get('market_cap_rank') or 9999):
    sym=(c.get('symbol') or '').lower()
    u=WRAP.get(sym)
    if u:
        if u in seen_underlying: continue
        seen_underlying.add(u)
    dd.append(c)
filtered=dd

by24 = sorted(filtered, key=lambda x: x['price_change_percentage_24h'])
losers = by24[:10]
winners = list(reversed(by24[-10:]))

# market pulse
top100 = sorted(filtered, key=lambda x: x.get('market_cap_rank') or 9999)[:100]
green = sum(1 for c in top100 if (c.get('price_change_percentage_24h') or 0) > 0)
top50 = top100[:50]
med_vals = sorted(c.get('price_change_percentage_24h') or 0 for c in top50)
median50 = med_vals[len(med_vals)//2] if med_vals else 0

# trending
trend=[]
for t in tr.get('coins',[]):
    it=t['item']
    trend.append({
        'name':it.get('name'),'symbol':(it.get('symbol') or '').upper(),
        'rank':it.get('market_cap_rank'),
        'price':(it.get('data') or {}).get('price'),
        'ch24':((it.get('data') or {}).get('price_change_percentage_24h') or {}).get('usd')
    })
trend=trend[:7]
trend_syms={t['symbol'] for t in trend}

def tags(c, is_winner, is_loser):
    t=[]
    ch1=c.get('price_change_percentage_1h_in_currency')
    ch24=c.get('price_change_percentage_24h') or 0
    ch7=c.get('price_change_percentage_7d_in_currency')
    rank=c.get('market_cap_rank') or 9999
    mcap=c.get('market_cap') or 0
    vol=c.get('total_volume') or 0
    sym=(c.get('symbol') or '').upper()
    if sym in trend_syms and is_winner: t.append('TRENDING+UP')
    if sym in trend_syms and is_loser: t.append('TRENDING+DOWN')
    if ch24>15 and (ch7 or 0)>25: t.append('BREAKOUT')
    if ch24>20 and (ch7 is not None and ch7<0): t.append('FADE')
    if ch24<-10 and mcap>0 and vol/mcap>0.25: t.append('CAPITULATION')
    if rank>150 and ch24>30: t.append('PUMP-RISK')
    if mcap>0 and mcap<50_000_000: t.append('MICROCAP')
    if rank<=20: t.append('MAJOR')
    return t[:2]

def fmt_price(p):
    if p is None: return 'n/a'
    if p>=1: return f"${p:,.2f}"
    if p>=0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_big(n):
    if n is None: return 'n/a'
    if n>=1e9: return f"${n/1e9:.1f}B"
    if n>=1e6: return f"${n/1e6:.0f}M"
    if n>=1e3: return f"${n/1e3:.0f}K"
    return f"${n:.0f}"

def line(c, i, is_w, is_l):
    ch1=c.get('price_change_percentage_1h_in_currency')
    ch24=c.get('price_change_percentage_24h') or 0
    ch7=c.get('price_change_percentage_7d_in_currency')
    tg=tags(c,is_w,is_l)
    tstr=('  ['+' '.join(tg)+']') if tg else ''
    ch7s=f"{ch7:+.1f}%" if ch7 is not None else "n/a"
    ch1s=f"{ch1:+.1f}%" if ch1 is not None else "n/a"
    return (f"{i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(c.get('current_price'))}  "
            f"{ch24:+.1f}% / 7d {ch7s} / 1h {ch1s}  •  {fmt_big(c.get('total_volume'))} / #{c.get('market_cap_rank')}{tstr}")

print(f"PULSE: green={green}/100 top-100, median top50 24h = {median50:+.2f}%")
print("\n=== WINNERS ===")
for i,c in enumerate(winners,1): print(line(c,i,True,False))
print("\n=== LOSERS ===")
for i,c in enumerate(losers,1): print(line(c,i,False,True))
print("\n=== TRENDING ===")
for i,t in enumerate(trend,1):
    tg=[]
    if t['symbol'] in {w['symbol'].upper() for w in winners}: tg.append('TRENDING+UP')
    if t['symbol'] in {w['symbol'].upper() for w in losers}: tg.append('TRENDING+DOWN')
    ch=t['ch24']
    chs=f"{ch:+.1f}%" if ch is not None else "n/a"
    pr=t['price']
    prs=fmt_price(pr) if pr else 'n/a'
    tstr=('  ['+' '.join(tg)+']') if tg else ''
    print(f"{i}. {t['name']} ({t['symbol']}) — #{t['rank']}, {prs}, 24h {chs}{tstr}")
PY_END=1
