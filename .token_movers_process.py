import json, urllib.request, urllib.error

MARKETS_URL = 'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d'
TRENDING_URL = 'https://api.coingecko.com/api/v3/search/trending'

def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode())

data = fetch(MARKETS_URL)
trending_data = fetch(TRENDING_URL)

stablecoins = {
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
    'binance-usd','frax','true-usd','gemini-dollar','terrausd','neutrino','fei-usd',
    'origin-dollar','liquity-usd','euro-coin','stasis-eurs','celo-dollar','nusd','susd',
    'usds','sky-1','ethena-usde','usual-usd','dollar-on-chain','usd-plus','crvusd','alusd',
    'msusd','usdx-money','eura','gho','deusd','tether-gold',
    'binance-peg-busd','binance-peg-usd','usdb','ondo-us-dollar-yield','bridged-usd-coin-base',
    'usd0','usd1','ageur'
}
wrapped = {
    'wrapped-bitcoin','wrapped-ethereum','wrapped-steth','staked-ether','wrapped-eeth',
    'rocket-pool-eth','coinbase-wrapped-staked-eth','wbtc','weth','weeth','reth','cbeth',
    'lido-staked-ether','mantle-staked-ether','bedrock-unieth','swell-ethereum',
    'renzo-restaked-eth','wrapped-liquid-staked-ether-2-0'
}

def is_noise(c):
    sym = c.get('symbol','').upper()
    name = (c.get('name') or '').lower()
    cid = c.get('id','')
    if cid in stablecoins or cid in wrapped:
        return True
    if sym.startswith(('USD','EUR','GBP')) or sym in ('USDT','USDC','BUSD','TUSD','USDP','USDD','FRAX','LUSD','DAI','EURS','FDUSD','USDE','PYUSD','PAXG','SUSD','GUSD','NUSD','CUSD'):
        return True
    if 'stablecoin' in name or 'pegged' in name:
        return True
    vol = c.get('total_volume') or 0
    if vol < 1_000_000:
        return True
    return False

filtered = [c for c in data if not is_noise(c)]

def pct24(c):
    return c.get('price_change_percentage_24h_in_currency') or c.get('price_change_percentage_24h') or 0

sorted_24h = sorted(filtered, key=pct24, reverse=True)

def fmt_price(p):
    if p is None:
        return 'N/A'
    if p >= 1000:
        return '$%s' % '{:,.0f}'.format(p)
    elif p >= 1:
        return '$%.4g' % p
    elif p >= 0.01:
        return '$%.4f' % p
    elif p >= 0.0001:
        return '$%.6f' % p
    else:
        return '$%.2e' % p

def fmt_vol(v):
    if v >= 1e9:
        return '$%.1fB' % (v/1e9)
    elif v >= 1e6:
        return '$%.0fM' % (v/1e6)
    else:
        return '$%.0fK' % (v/1e3)

def fmt_mcap(m):
    if m >= 1e9:
        return '$%.1fB' % (m/1e9)
    elif m >= 1e6:
        return '$%.0fM' % (m/1e6)
    else:
        return '$%.0fK' % (m/1e3)

winners = sorted_24h[:10]
losers = sorted_24h[-10:][::-1]
winner_ids = {c['id'] for c in winners}
loser_ids = {c['id'] for c in losers}

trending_coins = trending_data.get('coins', [])[:7]
trending_ids = {tc['item']['id'] for tc in trending_coins}

def get_tags(c):
    result = []
    cid = c['id']
    pct = pct24(c)
    p7d = c.get('price_change_percentage_7d_in_currency') or 0
    rank = c.get('market_cap_rank') or 999
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0

    is_trending = cid in trending_ids

    if is_trending and cid in winner_ids:
        result.append('[TRENDING+UP]')
    elif is_trending and cid in loser_ids:
        result.append('[TRENDING+DOWN]')

    if pct > 15 and p7d > 25:
        result.append('[BREAKOUT]')
    elif pct > 20 and p7d < 0:
        result.append('[FADE]')

    if pct < -10 and mcap > 0:
        vol_mcap_ratio = vol / mcap
        if vol_mcap_ratio > 0.25:
            result.append('[CAPITULATION]')

    if rank > 150 and pct > 30:
        result.append('[PUMP-RISK]')

    if mcap < 50_000_000:
        result.append('[MICROCAP]')
    elif rank <= 20:
        result.append('[MAJOR]')

    return result[:2]

print('=== WINNERS ===')
for i, c in enumerate(winners, 1):
    p1h = c.get('price_change_percentage_1h_in_currency') or 0
    p7d = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 0
    price = c.get('current_price') or 0
    pct = pct24(c)
    t = ' '.join(get_tags(c))
    print('%d|%s|%s|rank%d|%s|24h:%.1f%%|7d:%.1f%%|1h:%.1f%%|vol:%s|mcap:%s|id:%s|tags:%s' % (
        i, c['symbol'].upper(), c['name'], rank, fmt_price(price),
        pct, p7d, p1h, fmt_vol(vol), fmt_mcap(mcap), c['id'], t))

print('=== LOSERS ===')
for i, c in enumerate(losers, 1):
    p1h = c.get('price_change_percentage_1h_in_currency') or 0
    p7d = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 0
    price = c.get('current_price') or 0
    pct = pct24(c)
    t = ' '.join(get_tags(c))
    print('%d|%s|%s|rank%d|%s|24h:%.1f%%|7d:%.1f%%|1h:%.1f%%|vol:%s|mcap:%s|id:%s|tags:%s' % (
        i, c['symbol'].upper(), c['name'], rank, fmt_price(price),
        pct, p7d, p1h, fmt_vol(vol), fmt_mcap(mcap), c['id'], t))

print('=== TRENDING ===')
for i, tc in enumerate(trending_coins, 1):
    item = tc['item']
    tid = item.get('id','')
    tname = item.get('name','')
    tsym = item.get('symbol','').upper()
    trank = item.get('market_cap_rank') or 0
    tdata = item.get('data', {})
    tprice = tdata.get('price', 0)
    tpct24 = 0
    pct_data = tdata.get('price_change_percentage_24h', {})
    if isinstance(pct_data, dict):
        tpct24 = pct_data.get('usd', 0)
    elif isinstance(pct_data, (int, float)):
        tpct24 = pct_data
    t_tags = []
    if tid in winner_ids:
        t_tags.append('[TRENDING+UP]')
    elif tid in loser_ids:
        t_tags.append('[TRENDING+DOWN]')
    tag_str = ' '.join(t_tags)
    print('%d|%s|%s|rank%d|price:%.6g|24h:%.1f%%|id:%s|tags:%s' % (
        i, tname, tsym, trank, tprice, tpct24, tid, tag_str))

print('=== PULSE ===')
top100 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
pos = sum(1 for c in top100 if pct24(c) > 0)
top50 = sorted(top100, key=lambda c: c.get('market_cap_rank') or 999)[:50]
changes50 = sorted([pct24(c) for c in top50])
n = len(changes50)
med = changes50[n//2] if n > 0 else 0
print('pos%d/%d median%.1f%%' % (pos, len(top100), med))
