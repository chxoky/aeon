import json, statistics
D="/home/runner/work/aeon/aeon/.mp-tmp/"
d=json.load(open(D+"cg_markets.json"))
stable_ids={'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','ethena-usde','usds','sky-dollar','binance-usd','usdb','ripple-usd','usd1','global-dollar','falcon-finance','ondo-us-dollar-yield'}
def is_stable(c):
    sid=c['id']; sym=(c.get('symbol') or '').upper(); nm=(c.get('name') or '').lower()
    if sid in stable_ids: return True
    if sym.startswith(('USD','EUR','GBP')): return True
    if 'stablecoin' in nm: return True
    if nm in ('dai','paypal usd','first digital usd'): return True
    return False
rows=[]
for c in d:
    if is_stable(c): continue
    if (c.get('total_volume') or 0) < 1_000_000: continue
    rows.append(c)
def fmt(c):
    c7=c.get('price_change_percentage_7d_in_currency') or 0
    c1=c.get('price_change_percentage_1h_in_currency') or 0
    return f"{(c.get('symbol') or '').upper():8} {(c.get('name') or '')[:18]:18} #{c.get('market_cap_rank')} ${c.get('current_price'):.6g} 24h {c.get('price_change_percentage_24h_in_currency'):+.1f} 7d {c7:+.1f} 1h {c1:+.1f} vol${(c.get('total_volume') or 0)/1e6:.0f}M mcap${(c.get('market_cap') or 0)/1e6:.0f}M"
haved24=[r for r in rows if r.get('price_change_percentage_24h_in_currency') is not None]
wins=sorted(haved24, key=lambda c:c['price_change_percentage_24h_in_currency'], reverse=True)[:12]
loss=sorted(haved24, key=lambda c:c['price_change_percentage_24h_in_currency'])[:12]
print("=== WINNERS ===")
for c in wins: print(fmt(c))
print("=== LOSERS ===")
for c in loss: print(fmt(c))
top100=[c for c in d if c.get('market_cap_rank') and c['market_cap_rank']<=100 and not is_stable(c)]
green=sum(1 for c in top100 if (c.get('price_change_percentage_24h_in_currency') or 0)>0)
top50=[c for c in d if c.get('market_cap_rank') and c['market_cap_rank']<=50 and not is_stable(c)]
med=statistics.median([c.get('price_change_percentage_24h_in_currency') or 0 for c in top50])
print(f"=== BREADTH top100 green24h: {green}/{len(top100)}  median top50 24h: {med:+.2f}")
print("=== TOP 20 ===")
t20=[c for c in d if c.get('market_cap_rank') and c['market_cap_rank']<=20][:20]
g24=sum(1 for c in t20 if (c.get('price_change_percentage_24h_in_currency') or 0)>0)
g7=sum(1 for c in t20 if (c.get('price_change_percentage_7d_in_currency') or 0)>0)
for c in t20:
    print(f"{(c.get('symbol') or '').upper():6} ${c.get('current_price'):.6g} 24h {c.get('price_change_percentage_24h_in_currency') or 0:+.2f} 7d {c.get('price_change_percentage_7d_in_currency') or 0:+.2f}")
print(f"top20 green 24h {g24}/20  7d {g7}/20")
