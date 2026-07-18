import json

C = '.mp-cache/'
mk = json.load(open(C+'cg_markets.json'))
tr = json.load(open(C+'cg_trending.json'))
gl = json.load(open(C+'cg_global.json'))
fng = json.load(open(C+'fng.json'))

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','ethena-usde','usds','sky-dollar','binance-usd','true-usd','ripple-usd','usdt0'}
def is_stable(c):
    sym = (c.get('symbol') or '').upper()
    name = (c.get('name') or '').lower()
    if c.get('id') in STABLE_IDS: return True
    if sym.startswith(('USD','EUR','GBP')): return True
    if 'stablecoin' in name or 'staked ether' in name or 'wrapped' in name: return True
    return False

filt = [c for c in mk if not is_stable(c) and (c.get('total_volume') or 0) >= 1_000_000]

def ch24(c):
    v=c.get('price_change_percentage_24h_in_currency')
    return v if v is not None else (c.get('price_change_percentage_24h') or 0)
def ch7(c):
    v=c.get('price_change_percentage_7d_in_currency')
    return v if v is not None else 0
def ch1(c):
    v=c.get('price_change_percentage_1h_in_currency')
    return v if v is not None else 0

winners = sorted(filt, key=ch24, reverse=True)[:10]
losers = sorted(filt, key=ch24)[:10]

def fmt_price(p):
    if p is None: return "n/a"
    if p >= 1: return "$%s" % format(round(p,2), ',')
    if p >= 0.01: return "$%.4f" % p
    return "$%.6f" % p
def fmt_big(n):
    if n is None: return "n/a"
    if n>=1e12: return "$%.2fT" % (n/1e12)
    if n>=1e9: return "$%.1fB" % (n/1e9)
    if n>=1e6: return "$%.0fM" % (n/1e6)
    return "$%.0fK" % (n/1e3)

trending_ids = set()
trending_list = []
for item in tr.get('coins',[])[:7]:
    it = item.get('item',{})
    trending_ids.add(it.get('id'))
    d = it.get('data',{})
    trending_list.append({
        'name': it.get('name'), 'symbol': (it.get('symbol') or '').upper(),
        'rank': it.get('market_cap_rank'), 'price': d.get('price'),
        'ch24': (d.get('price_change_percentage_24h') or {}).get('usd')
    })

def tags(c):
    t=[]
    r=c.get('market_cap_rank') or 999
    mc=c.get('market_cap') or 0
    c24,c7=ch24(c),ch7(c)
    vol=c.get('total_volume') or 0
    intr = c.get('id') in trending_ids
    if intr and c24>0: t.append('TRENDING+UP')
    if intr and c24<0: t.append('TRENDING+DOWN')
    if c24>15 and c7>25: t.append('BREAKOUT')
    if c24>20 and c7<0: t.append('FADE')
    if c24<-10 and mc>0 and vol/mc>0.25: t.append('CAPITULATION')
    if r>150 and c24>30: t.append('PUMP-RISK')
    if mc<50_000_000: t.append('MICROCAP')
    if r<=20: t.append('MAJOR')
    return t[:2]

print("===== WINNERS =====")
for c in winners:
    print("%s (%s) | %s | 24h %+.1f%% 7d %+.1f%% 1h %+.1f%% | vol %s mc %s #%s | %s" % (c['symbol'].upper(), c['name'], fmt_price(c.get('current_price')), ch24(c), ch7(c), ch1(c), fmt_big(c.get('total_volume')), fmt_big(c.get('market_cap')), c.get('market_cap_rank'), tags(c)))
print("\n===== LOSERS =====")
for c in losers:
    print("%s (%s) | %s | 24h %+.1f%% 7d %+.1f%% 1h %+.1f%% | vol %s mc %s #%s | %s" % (c['symbol'].upper(), c['name'], fmt_price(c.get('current_price')), ch24(c), ch7(c), ch1(c), fmt_big(c.get('total_volume')), fmt_big(c.get('market_cap')), c.get('market_cap_rank'), tags(c)))
print("\n===== TRENDING =====")
for t in trending_list:
    ch = t['ch24']
    chs = ("%+.1f%%" % ch) if ch is not None else "n/a"
    print("%s (%s) #%s %s 24h %s" % (t['name'], t['symbol'], t['rank'], fmt_price(t['price']), chs))

top100 = filt[:100]
green100 = sum(1 for c in top100 if ch24(c)>0)
top50 = filt[:50]
med50 = sorted([ch24(c) for c in top50])[len(top50)//2] if top50 else 0
print("\n===== PULSE ===== top100 green: %s/%s, median top50 24h: %+.2f%%" % (green100, len(top100), med50))

byid = {c['id']:c for c in mk}
print("\n===== MAJORS =====")
for cid in ['bitcoin','ethereum','solana']:
    c=byid.get(cid)
    if c: print("%s: %s 24h %+.2f%% 7d %+.2f%% mc %s" % (cid, fmt_price(c.get('current_price')), ch24(c), ch7(c), fmt_big(c.get('market_cap'))))

top20 = mk[:20]
g24 = sum(1 for c in top20 if ch24(c)>0)
g7 = sum(1 for c in top20 if ch7(c)>0)
print("\n===== BREADTH ===== %s/20 green 24h, %s/20 green 7d" % (g24, g7))

gd = gl.get('data',{})
print("\n===== GLOBAL =====")
print("total mcap: %s" % fmt_big(gd.get('total_market_cap',{}).get('usd')))
print("mcap 24h change: %+.2f%%" % gd.get('market_cap_change_percentage_24h_usd'))
print("BTC dominance: %.2f%%" % gd.get('market_cap_percentage',{}).get('btc'))
print("ETH dominance: %.2f%%" % gd.get('market_cap_percentage',{}).get('eth'))
print("total 24h vol: %s" % fmt_big(gd.get('total_volume',{}).get('usd')))

btc=byid.get('bitcoin'); eth=byid.get('ethereum')
if btc and eth:
    print("ETH/BTC: %.4f" % (eth['current_price']/btc['current_price']))

print("\n===== FNG =====")
for d in fng.get('data',[]):
    print("%s (%s) ts %s" % (d.get('value'), d.get('value_classification'), d.get('timestamp')))
