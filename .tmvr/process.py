import json

m = json.load(open('.tmvr/markets.json'))
t = json.load(open('.tmvr/trending.json'))

if not isinstance(m, list) or len(m) < 50:
    print("MARKETS_BAD")
    raise SystemExit

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','ethena-usde','binance-usd','usds','usd0','crvusd','gho','frax','lusd'}
def is_stable(c):
    cid = (c.get('id') or '').lower()
    sym = (c.get('symbol') or '').upper()
    name = (c.get('name') or '').lower()
    if cid in STABLE_IDS: return True
    if sym.startswith(('USD','EUR','GBP')): return True
    if 'usd' in cid and ('tether' in cid or 'coin' in cid or 'dollar' in cid): return True
    if 'stablecoin' in name or 'stable' in name: return True
    return False

WRAPPED = {'wbtc','weth','steth','wsteth','weeth','wbeth','reth','cbbtc','lbtc','bsc-usd','coinbase-wrapped-btc','wrapped-steth','wrapped-bitcoin','staked-ether','rocket-pool-eth','binance-peg-weth','wrapped-eeth'}

rows = []
for c in m:
    if is_stable(c): continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    cid = (c.get('id') or '').lower()
    if cid in WRAPPED: continue
    rows.append(c)

def g(c,k):
    v=c.get(k)
    return v if isinstance(v,(int,float)) else 0.0

byd = sorted(rows, key=lambda c: g(c,'price_change_percentage_24h_in_currency'))
losers = byd[:10]
winners = list(reversed(byd[-10:]))

trending = []
for item in t.get('coins',[])[:7]:
    ci = item.get('item',{})
    d = ci.get('data',{})
    pc = d.get('price_change_percentage_24h')
    ch = pc.get('usd') if isinstance(pc,dict) else None
    trending.append({
        'name': ci.get('name'),
        'symbol': (ci.get('symbol') or '').upper(),
        'rank': ci.get('market_cap_rank'),
        'price': (d.get('price') if isinstance(d.get('price'),(int,float)) else None),
        'ch24': ch,
        'id': ci.get('id'),
    })

trending_ids = {x['id'] for x in trending}

def fmt_price(p):
    if p is None: return 'n/a'
    if p >= 1000: return f"${p:,.0f}"
    if p >= 1: return f"${p:,.2f}"
    if p >= 0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_big(v):
    if not v: return 'n/a'
    if v>=1e9: return f"${v/1e9:.1f}B"
    if v>=1e6: return f"${v/1e6:.0f}M"
    if v>=1e3: return f"${v/1e3:.0f}K"
    return f"${v:.0f}"

def tags(c):
    tg=[]
    ch24=g(c,'price_change_percentage_24h_in_currency')
    ch7=g(c,'price_change_percentage_7d_in_currency')
    rank=c.get('market_cap_rank') or 9999
    mcap=g(c,'market_cap')
    vol=g(c,'total_volume')
    cid=(c.get('id') or '').lower()
    if cid in trending_ids and ch24>0: tg.append('TRENDING+UP')
    if cid in trending_ids and ch24<0: tg.append('TRENDING+DOWN')
    if ch24>15 and ch7>25: tg.append('BREAKOUT')
    if ch24>20 and ch7<0: tg.append('FADE')
    if ch24<-10 and mcap>0 and (vol/mcap)>0.25: tg.append('CAPITULATION')
    if rank>150 and ch24>30: tg.append('PUMP-RISK')
    if mcap>0 and mcap<50_000_000: tg.append('MICROCAP')
    if rank<=20: tg.append('MAJOR')
    pri=[x for x in tg if x=='PUMP-RISK']
    rest=[x for x in tg if x!='PUMP-RISK']
    return (pri+rest)[:2]

def line(i,c):
    sym=(c.get('symbol') or '').upper()
    name=c.get('name')
    p=fmt_price(c.get('current_price'))
    ch24=g(c,'price_change_percentage_24h_in_currency')
    ch7=g(c,'price_change_percentage_7d_in_currency')
    ch1=g(c,'price_change_percentage_1h_in_currency')
    vol=fmt_big(g(c,'total_volume'))
    rank=c.get('market_cap_rank')
    tg=tags(c)
    ts=('  ['+', '.join(tg)+']') if tg else ''
    s24=f"+{ch24:.1f}%" if ch24>=0 else f"{ch24:.1f}%"
    s7=f"+{ch7:.1f}%" if ch7>=0 else f"{ch7:.1f}%"
    s1=f"+{ch1:.1f}%" if ch1>=0 else f"{ch1:.1f}%"
    return f"{i}. {sym} ({name}) — {p}  {s24} / 7d {s7} / 1h {s1}  •  {vol} / #{rank}{ts}"

top100 = rows[:100]
green = sum(1 for c in top100 if g(c,'price_change_percentage_24h_in_currency')>0)
top50 = rows[:50]
meds = sorted(g(c,'price_change_percentage_24h_in_currency') for c in top50)
med = meds[len(meds)//2] if meds else 0
btc = next((c for c in m if c.get('id')=='bitcoin'), None)
eth = next((c for c in m if c.get('id')=='ethereum'), None)
btc24 = g(btc,'price_change_percentage_24h_in_currency') if btc else 0
eth24 = g(eth,'price_change_percentage_24h_in_currency') if eth else 0

print("=== PULSE DATA ===")
print(f"green {green}/{len(top100)}  median_top50 {med:.2f}%")
print(f"BTC {fmt_price(btc.get('current_price')) if btc else 'na'} {btc24:+.1f}%   ETH {fmt_price(eth.get('current_price')) if eth else 'na'} {eth24:+.1f}%")
print()
print("=== WINNERS ===")
for i,c in enumerate(winners,1): print(line(i,c))
print()
print("=== LOSERS ===")
for i,c in enumerate(losers,1): print(line(i,c))
print()
print("=== TRENDING ===")
for i,x in enumerate(trending,1):
    ch=x['ch24']
    chs=f"{ch:+.1f}%" if isinstance(ch,(int,float)) else 'n/a'
    intr = ' [TRENDING+UP]' if (isinstance(ch,(int,float)) and ch>0) else (' [TRENDING+DOWN]' if isinstance(ch,(int,float)) and ch<0 else '')
    print(f"{i}. {x['name']} ({x['symbol']}) — #{x['rank']}, {fmt_price(x['price'])}, 24h {chs}{intr}")
print()
print("=== NOTABLE-CANDIDATES ===")
for c in winners+losers:
    tg=tags(c)
    if any(z in tg for z in ('TRENDING+UP','TRENDING+DOWN','BREAKOUT','CAPITULATION','PUMP-RISK','FADE')):
        sym=(c.get('symbol') or '').upper()
        ch24=g(c,'price_change_percentage_24h_in_currency')
        ch7=g(c,'price_change_percentage_7d_in_currency')
        print(f"{sym}: 24h {ch24:+.1f}% 7d {ch7:+.1f}% rank #{c.get('market_cap_rank')} vol {fmt_big(g(c,'total_volume'))} tags {tg}")
