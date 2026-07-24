import json, sys

data = json.load(sys.stdin)

STABLECOIN_IDS = {'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','binance-peg-busd','binance-peg-usd','usdb','ethena-usde','usual-usd','ondo-us-dollar-yield','bridged-usd-coin-base','tether-gold'}
WRAPPED = {'wrapped-bitcoin','wrapped-ethereum','staked-ether','wrapped-steth','coinbase-wrapped-staked-eth','wrapped-eeth','renzo-restaked-eth','mantle-staked-ether','bedrock-unieth','swell-ethereum','lido-staked-ether'}
STABLE_SYMS = {'USDT','USDC','BUSD','TUSD','USDP','USDD','FRAX','LUSD','DAI','EURS','USDN','FDUSD','USDCE','USDE','PYUSD','PAXG','USDY','SUSD','ALUSD','GUSD','HUSD','USDX','NUSD','CUSD','EUSD','CRVUSD','MKUSD','GHO','DOLA','USDe','USDS','USD0','USD1'}

def is_stable(coin):
    s = coin['symbol'].upper()
    n = coin['name'].lower()
    return (coin['id'] in STABLECOIN_IDS or
            s in STABLE_SYMS or
            s.startswith('USD') or
            'stablecoin' in n)

filtered = [c for c in data
            if c['id'] not in STABLECOIN_IDS
            and c['id'] not in WRAPPED
            and not is_stable(c)
            and (c.get('total_volume') or 0) >= 1_000_000]

sorted_winners = sorted([c for c in filtered if c.get('price_change_percentage_24h_in_currency') is not None],
                        key=lambda x: x['price_change_percentage_24h_in_currency'], reverse=True)
sorted_losers = sorted([c for c in filtered if c.get('price_change_percentage_24h_in_currency') is not None],
                       key=lambda x: x['price_change_percentage_24h_in_currency'])

def fmt_price(p):
    if p is None: return 'N/A'
    if p >= 1000: return '$%s' % '{:,.0f}'.format(p)
    if p >= 1: return '$%.4g' % p
    if p >= 0.01: return '$%.4f' % p
    return '$%.6f' % p

def fmt_vol(v):
    if v >= 1e9: return '$%.2fB' % (v/1e9)
    if v >= 1e6: return '$%.1fM' % (v/1e6)
    return '$%.0fK' % (v/1e3)

def fmt_pct(p):
    if p is None: return 'N/A'
    sign = '+' if p >= 0 else ''
    return '%s%.1f%%' % (sign, p)

top100 = sorted(filtered, key=lambda x: x.get('market_cap_rank') or 9999)[:100]
top50 = top100[:50]
green100 = sum(1 for c in top100 if (c.get('price_change_percentage_24h_in_currency') or 0) > 0)
changes50 = sorted([c.get('price_change_percentage_24h_in_currency') or 0 for c in top50])
median50 = changes50[len(changes50)//2]

print('PULSE|%d/100 positive 24h median-top50:%.2f%%' % (green100, median50))

for i, c in enumerate(sorted_winners[:12]):
    ch1h = c.get('price_change_percentage_1h_in_currency')
    ch24 = c.get('price_change_percentage_24h_in_currency')
    ch7d = c.get('price_change_percentage_7d_in_currency')
    vol = c.get('total_volume') or 0
    rank = c.get('market_cap_rank') or 999
    price = c.get('current_price')
    mcap = c.get('market_cap') or 0
    print('W|%d|%s|%s|rank%d|%s|24h:%s|7d:%s|1h:%s|vol:%s|mcap:%.0f' % (
        i+1, c['symbol'].upper(), c['name'], rank, fmt_price(price),
        fmt_pct(ch24), fmt_pct(ch7d), fmt_pct(ch1h), fmt_vol(vol), mcap))

for i, c in enumerate(sorted_losers[:12]):
    ch1h = c.get('price_change_percentage_1h_in_currency')
    ch24 = c.get('price_change_percentage_24h_in_currency')
    ch7d = c.get('price_change_percentage_7d_in_currency')
    vol = c.get('total_volume') or 0
    rank = c.get('market_cap_rank') or 999
    price = c.get('current_price')
    mcap = c.get('market_cap') or 0
    print('L|%d|%s|%s|rank%d|%s|24h:%s|7d:%s|1h:%s|vol:%s|mcap:%.0f' % (
        i+1, c['symbol'].upper(), c['name'], rank, fmt_price(price),
        fmt_pct(ch24), fmt_pct(ch7d), fmt_pct(ch1h), fmt_vol(vol), mcap))
