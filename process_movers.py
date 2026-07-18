import json

m = json.load(open('markets.json'))
tr = json.load(open('trending.json'))

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
              'ethena-usde','binance-usd','usdt','staked-ether','wrapped-steth','wrapped-beacon-eth',
              'blackrock-usd-institutional-digital-liquidity-fund','ripple-usd','usds','sky-dollar'}
WRAPPED_IDS = {'wrapped-bitcoin','weth','wrapped-eth','staked-ether','wrapped-steth','coinbase-wrapped-btc',
               'wrapped-beacon-eth','binance-bridged-usdt-bnb-smart-chain','lombard-staked-btc',
               'wrapped-eeth','rocket-pool-eth','mantle-staked-ether','bridged-wrapped-steth-axelar',
               'solv-btc','kelp-dao-restaked-eth','renzo-restaked-eth','jupiter-staked-sol','jito-staked-sol',
               'binance-staked-sol','msol','coinbase-wrapped-staked-eth','tbtc','wrapped-avax'}

def is_stable(c):
    sym=(c.get('symbol') or '').upper()
    name=(c.get('name') or '').lower()
    cid=c.get('id') or ''
    if cid in STABLE_IDS: return True
    if 'stablecoin' in name or 'usd ' in name.lower(): return True
    for p in ('USD','EUR','GBP'):
        if sym.startswith(p): return True
    return False

filt=[]
for c in m:
    if is_stable(c): continue
    if c.get('id') in WRAPPED_IDS: continue
    vol=c.get('total_volume') or 0
    if vol < 1_000_000: continue
    if c.get('price_change_percentage_24h') is None: continue
    filt.append(c)

print("filtered:",len(filt))

by24 = [c for c in filt if c.get('price_change_percentage_24h_in_currency') is not None or c.get('price_change_percentage_24h') is not None]

def p24(c): return c.get('price_change_percentage_24h_in_currency') if c.get('price_change_percentage_24h_in_currency') is not None else c.get('price_change_percentage_24h')
def p7(c): return c.get('price_change_percentage_7d_in_currency')
def p1(c): return c.get('price_change_percentage_1h_in_currency')

srt=sorted(by24,key=lambda c:p24(c))
losers=srt[:10]
winners=list(reversed(srt[-10:]))

# trending
trending=[]
for item in tr.get('coins',[]):
    it=item['item']
    d=it.get('data',{})
    trending.append({
        'name':it.get('name'),'symbol':(it.get('symbol') or '').upper(),
        'rank':it.get('market_cap_rank'),
        'price':d.get('price'),
        'p24':(d.get('price_change_percentage_24h') or {}).get('usd'),
        'id':it.get('id')
    })
trending=trending[:7]

trending_ids={t['id'] for t in trending}
trending_syms={t['symbol'] for t in trending}

# market pulse
top100=filt[:100]
green=sum(1 for c in top100 if (p24(c) or 0)>0)
top50=filt[:50]
med_vals=sorted(p24(c) for c in top50)
n=len(med_vals)
median50=med_vals[n//2] if n%2 else (med_vals[n//2-1]+med_vals[n//2])/2

def tags(c,is_winner=None):
    t=[]
    v24=p24(c) or 0
    v7=p7(c)
    rank=c.get('market_cap_rank') or 9999
    mcap=c.get('market_cap') or 0
    vol=c.get('total_volume') or 0
    intrend=c.get('id') in trending_ids or (c.get('symbol') or '').upper() in trending_syms
    if intrend and v24>0: t.append('TRENDING+UP')
    if intrend and v24<0: t.append('TRENDING+DOWN')
    if v24>15 and (v7 or 0)>25: t.append('BREAKOUT')
    if v24>20 and v7 is not None and v7<0: t.append('FADE')
    if v24<-10 and mcap>0 and vol/mcap>0.25: t.append('CAPITULATION')
    if rank>150 and v24>30: t.append('PUMP-RISK')
    if mcap>0 and mcap<50_000_000: t.append('MICROCAP')
    if rank<=20: t.append('MAJOR')
    # priority: keep PUMP-RISK always, cap at 2
    if 'PUMP-RISK' in t:
        rest=[x for x in t if x!='PUMP-RISK']
        t=['PUMP-RISK']+rest
    return t[:2]

def fmt_price(p):
    if p is None: return '?'
    if p>=1000: return f"${p:,.0f}"
    if p>=1: return f"${p:,.2f}"
    if p>=0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_big(v):
    if v is None: return '?'
    if v>=1e9: return f"${v/1e9:.1f}B"
    if v>=1e6: return f"${v/1e6:.0f}M"
    return f"${v/1e3:.0f}K"

def line(c,i):
    v24=p24(c); v7=p7(c); v1=p1(c)
    tg=tags(c)
    tstr=('  ['+', '.join(tg)+']') if tg else ''
    s7='7d '+(f"{v7:+.0f}%" if v7 is not None else 'n/a')
    s1='1h '+(f"{v1:+.1f}%" if v1 is not None else 'n/a')
    return f"{i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(c.get('current_price'))}  {v24:+.1f}% / {s7} / {s1}  •  {fmt_big(c.get('total_volume'))} / #{c.get('market_cap_rank')}{tstr}"

print("\n=== PULSE ===")
print(f"green top100: {green}/100, median top50: {median50:+.2f}%")
print("\n=== WINNERS ===")
for i,c in enumerate(winners,1): print(line(c,i))
print("\n=== LOSERS ===")
for i,c in enumerate(losers,1): print(line(c,i))
print("\n=== TRENDING ===")
for i,t in enumerate(trending,1):
    tg=[]
    if t['symbol'] in {w['symbol'].upper() for w in winners}: tg.append('TRENDING+UP')
    if t['symbol'] in {l['symbol'].upper() for l in losers}: tg.append('TRENDING+DOWN')
    p=t['price']
    ps=fmt_price(p) if isinstance(p,(int,float)) else str(p)
    v=t['p24']
    vs=f"{v:+.1f}%" if isinstance(v,(int,float)) else 'n/a'
    tstr=('  ['+', '.join(tg)+']') if tg else ''
    print(f"{i}. {t['name']} ({t['symbol']}) — #{t['rank']}, {ps}, 24h {vs}{tstr}")
