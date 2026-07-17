import json

m = json.load(open('.tm-markets.json'))
if not isinstance(m, list):
    print("MARKETS_ERROR", str(m)[:300])
    raise SystemExit(1)

try:
    t = json.load(open('.tm-trending.json'))
    trending_coins = t.get('coins', [])
except Exception as e:
    trending_coins = None

print("markets_count", len(m))

STABLE_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd',
    'pyusd','fdusd','paxg','ethena-usde','usdt','binance-peg-busd','crypto-com-staked-eth',
    'blackrock-usd-institutional-digital-liquidity-fund','ondo-us-dollar-yield','usds',
    'sky-dollar','ripple-usd','rlusd','global-dollar','usd1-world-liberty-financial'}
WRAPPED = {'wbtc','weth','steth','wsteth','weeth','reth','cbbtc','wbeth','lbtc','solvbtc',
    'binance-bridged-usdt-bnb-smart-chain','coinbase-wrapped-btc','rseth','meth','msol','jitosol','bsc-usd','usdt0'}

def is_stable(c):
    sym = (c.get('symbol') or '').lower()
    name = (c.get('name') or '').lower()
    cid = (c.get('id') or '').lower()
    if cid in STABLE_IDS: return True
    if sym.startswith('usd') or sym.startswith('eur') or sym.startswith('gbp'): return True
    if 'stablecoin' in name or 'usd' in name and 'dollar' in name: return True
    if cid in ('paxos-gold','tether-gold'): return True
    return False

filtered = []
for c in m:
    if is_stable(c): continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    if c.get('price_change_percentage_24h_in_currency') is None: continue
    filtered.append(c)

# dedupe wrapped: keep only one representative among wrapped set (drop wrapped dupes)
filtered = [c for c in filtered if (c.get('id') or '').lower() not in WRAPPED]

print("filtered_count", len(filtered))

def p24(c): return c.get('price_change_percentage_24h_in_currency') or 0
def p7(c): return c.get('price_change_percentage_7d_in_currency') or 0
def p1(c): return c.get('price_change_percentage_1h_in_currency') or 0

winners = sorted(filtered, key=p24, reverse=True)[:10]
losers = sorted(filtered, key=p24)[:10]

# market pulse: top 100 by mcap after filters
top100 = sorted(filtered, key=lambda c: c.get('market_cap_rank') or 9999)[:100]
green = sum(1 for c in top100 if p24(c) > 0)
top50 = top100[:50]
med50 = sorted(p24(c) for c in top50)
n = len(med50)
median50 = (med50[n//2] if n%2 else (med50[n//2-1]+med50[n//2])/2) if n else 0

print("pulse_green", green, "of", len(top100), "median50", round(median50,2))

# trending symbols set
trend_syms = set()
trend_list = []
if trending_coins:
    for tc in trending_coins[:7]:
        item = tc.get('item', {})
        trend_syms.add((item.get('symbol') or '').upper())
        trend_list.append(item)

def fmt_price(p):
    if p is None: return "?"
    if p >= 1000: return f"${p:,.0f}"
    if p >= 1: return f"${p:,.2f}"
    if p >= 0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_big(v):
    if v is None: return "?"
    if v >= 1e9: return f"${v/1e9:.1f}B"
    if v >= 1e6: return f"${v/1e6:.0f}M"
    if v >= 1e3: return f"${v/1e3:.0f}K"
    return f"${v:.0f}"

def tags(c):
    tg = []
    sym = (c.get('symbol') or '').upper()
    rank = c.get('market_cap_rank') or 9999
    mcap = c.get('market_cap') or 0
    vol = c.get('total_volume') or 0
    a,b,h = p24(c), p7(c), p1(c)
    in_trend = sym in trend_syms
    if in_trend and a > 0: tg.append('TRENDING+UP')
    if in_trend and a < 0: tg.append('TRENDING+DOWN')
    if a > 15 and b > 25: tg.append('BREAKOUT')
    if a > 20 and b < 0: tg.append('FADE')
    if a < -10 and mcap and vol/mcap > 0.25: tg.append('CAPITULATION')
    if rank > 150 and a > 30: tg.append('PUMP-RISK')
    if mcap < 50_000_000: tg.append('MICROCAP')
    if rank <= 20: tg.append('MAJOR')
    return tg[:2]

def line(c, i):
    sym = (c.get('symbol') or '').upper()
    name = c.get('name')
    rank = c.get('market_cap_rank')
    tg = tags(c)
    tstr = ("  [" + ", ".join(tg) + "]") if tg else ""
    return (f"{i}. {sym} ({name}) — {fmt_price(c.get('current_price'))}  "
            f"{p24(c):+.1f}% / 7d {p7(c):+.1f}% / 1h {p1(c):+.1f}%  •  "
            f"{fmt_big(c.get('total_volume'))} / #{rank}{tstr}")

print("\n=== WINNERS ===")
for i,c in enumerate(winners,1): print(line(c,i))
print("\n=== LOSERS ===")
for i,c in enumerate(losers,1): print(line(c,i))

print("\n=== TRENDING ===")
if trending_coins is None:
    print("TRENDING_UNAVAILABLE")
else:
    for i,item in enumerate(trend_list,1):
        sym = (item.get('symbol') or '').upper()
        name = item.get('name')
        rank = item.get('market_cap_rank')
        data = item.get('data') or {}
        price = data.get('price')
        ch = None
        pcp = data.get('price_change_percentage_24h') or {}
        if isinstance(pcp, dict): ch = pcp.get('usd')
        chs = f"{ch:+.1f}%" if ch is not None else "?"
        print(f"{i}. {name} ({sym}) — #{rank if rank else '?'}, {fmt_price(price)}, 24h {chs}")

# Notable: coins with strong tags
print("\n=== NOTABLE ===")
notable_tags = {'TRENDING+UP','BREAKOUT','CAPITULATION','PUMP-RISK','TRENDING+DOWN'}
seen=set()
for c in winners+losers:
    tg = tags(c)
    sym=(c.get('symbol') or '').upper()
    if sym in seen: continue
    hit = [x for x in tg if x in notable_tags]
    if hit:
        seen.add(sym)
        print(f"{sym}: {p24(c):+.1f}% 24h / {p7(c):+.1f}% 7d, vol {fmt_big(c.get('total_volume'))}, #{c.get('market_cap_rank')} — {'/'.join(hit)}")
