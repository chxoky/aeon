import json, sys

# Load the markets data
markets_path = sys.argv[1]
trending_path = sys.argv[2]

with open(markets_path) as f:
    data = json.load(f)

with open(trending_path) as f:
    trending_raw = json.load(f)

# Stablecoins to exclude
STABLE_IDS = {
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
    'binance-usd','usdc','frax','gusd','susd','dollar-on-chain','usd-balance'
}
STABLE_SYMBOLS = {'usdt','usdc','busd','dai','frax','gusd','susd','tusd','usdp','usde','fdusd','pyusd','usdd','paxg'}
WRAPPED_IDS = {'wrapped-bitcoin','wrapped-ethereum','staked-ether','rocket-pool-eth','lido-staked-ether'}

def is_stable(c):
    sid = c['id'].lower()
    sym = c['symbol'].lower()
    name = c.get('name','').lower()
    if sid in STABLE_IDS: return True
    if sym in STABLE_SYMBOLS: return True
    if sym.startswith('usd') or sym.startswith('eur') or sym.startswith('gbp'): return True
    if 'stablecoin' in name: return True
    return False

def is_wrapped(c):
    return c['id'] in WRAPPED_IDS

# Filter
filtered = []
for c in data:
    if is_stable(c): continue
    if is_wrapped(c): continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000: continue
    chg_24h = c.get('price_change_percentage_24h_in_currency')
    if chg_24h is None: continue
    filtered.append(c)

# Sort by 24h change
sorted_up = sorted(filtered, key=lambda c: c['price_change_percentage_24h_in_currency'], reverse=True)
sorted_down = sorted(filtered, key=lambda c: c['price_change_percentage_24h_in_currency'])

top_winners = sorted_up[:10]
top_losers = sorted_down[:10]

# Market pulse: top 100 by mcap rank (filtered, already ordered by mcap_rank from API)
top100 = filtered[:100]
green_count = sum(1 for c in top100 if c['price_change_percentage_24h_in_currency'] > 0)
changes_50 = sorted([c['price_change_percentage_24h_in_currency'] for c in filtered[:50]])
median_50 = changes_50[len(changes_50)//2]

# Build set of winner/loser symbols for trending cross-reference
winner_symbols = {c['symbol'].lower() for c in top_winners}
loser_symbols = {c['symbol'].lower() for c in top_losers}

# Parse trending
trending_coins = []
for item in trending_raw.get('coins', [])[:7]:
    it = item.get('item', {})
    d = it.get('data', {})
    price = d.get('price', 0)
    chg_data = d.get('price_change_percentage_24h', {})
    chg24 = chg_data.get('usd', 0) if isinstance(chg_data, dict) else 0
    trending_coins.append({
        'id': it.get('id',''),
        'name': it.get('name',''),
        'symbol': it.get('symbol','').upper(),
        'rank': it.get('market_cap_rank') or 999,
        'price': price,
        'chg24': chg24,
    })

trending_symbols = {tc['symbol'].lower() for tc in trending_coins}

def fmt_price(p):
    if p is None: return 'N/A'
    if p >= 1000: return f"${p:,.0f}"
    if p >= 1: return f"${p:.4g}"
    if p >= 0.01: return f"${p:.4f}"
    return f"${p:.6f}"

def fmt_vol(v):
    if v >= 1e9: return f"${v/1e9:.1f}B"
    if v >= 1e6: return f"${v/1e6:.0f}M"
    return f"${v/1e3:.0f}K"

def get_tags(c, trending_syms, winner_syms, loser_syms):
    tags = []
    chg24 = c['price_change_percentage_24h_in_currency']
    chg7 = c.get('price_change_percentage_7d_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 1
    mcap_rank = c.get('market_cap_rank') or 999
    vol_mcap_ratio = vol / mcap if mcap > 0 else 0
    sym = c['symbol'].lower()

    trending_match = sym in trending_syms
    is_winner = sym in winner_syms
    is_loser = sym in loser_syms

    if trending_match and is_winner: tags.append('[TRENDING+UP]')
    if trending_match and is_loser: tags.append('[TRENDING+DOWN]')
    if chg24 > 15 and chg7 > 25: tags.append('[BREAKOUT]')
    elif chg24 > 20 and chg7 < 0: tags.append('[FADE]')
    if chg24 < -10 and vol_mcap_ratio > 0.25: tags.append('[CAPITULATION]')
    if mcap_rank > 150 and chg24 > 30: tags.append('[PUMP-RISK]')
    if mcap < 50e6: tags.append('[MICROCAP]')
    if mcap_rank <= 20: tags.append('[MAJOR]')

    return tags[:2]

print("PULSE")
print(f"green={green_count}/100 median50={median_50:.1f}%")
print()

print("WINNERS")
for i, c in enumerate(top_winners, 1):
    chg24 = c['price_change_percentage_24h_in_currency']
    chg7 = c.get('price_change_percentage_7d_in_currency') or 0
    chg1 = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap_rank = c.get('market_cap_rank') or 999
    price = c.get('current_price') or 0
    mcap = c.get('market_cap') or 0
    vol_mcap_ratio = vol / mcap if mcap > 0 else 0
    tags = get_tags(c, trending_symbols, winner_symbols, loser_symbols)
    tag_str = ' '.join(tags)
    print(f"{i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(price)} +{chg24:.1f}% / 7d {chg7:+.1f}% / 1h {chg1:+.1f}%  •  {fmt_vol(vol)} / #{mcap_rank}  {tag_str}")
    # extra for notable detection
    print(f"   _meta rank={mcap_rank} chg24={chg24:.1f} chg7={chg7:.1f} volmcap={vol_mcap_ratio:.3f} mcap_usd={mcap:.0f}")

print()
print("LOSERS")
for i, c in enumerate(top_losers, 1):
    chg24 = c['price_change_percentage_24h_in_currency']
    chg7 = c.get('price_change_percentage_7d_in_currency') or 0
    chg1 = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap_rank = c.get('market_cap_rank') or 999
    price = c.get('current_price') or 0
    mcap = c.get('market_cap') or 0
    vol_mcap_ratio = vol / mcap if mcap > 0 else 0
    tags = get_tags(c, trending_symbols, winner_symbols, loser_symbols)
    tag_str = ' '.join(tags)
    print(f"{i}. {c['symbol'].upper()} ({c['name']}) — {fmt_price(price)} {chg24:.1f}% / 7d {chg7:+.1f}% / 1h {chg1:+.1f}%  •  {fmt_vol(vol)} / #{mcap_rank}  {tag_str}")
    print(f"   _meta rank={mcap_rank} chg24={chg24:.1f} chg7={chg7:.1f} volmcap={vol_mcap_ratio:.3f} mcap_usd={mcap:.0f}")

print()
print("TRENDING")
for i, tc in enumerate(trending_coins, 1):
    sym = tc['symbol'].lower()
    tags = []
    if sym in winner_symbols: tags.append('[TRENDING+UP]')
    if sym in loser_symbols: tags.append('[TRENDING+DOWN]')
    if tc['rank'] > 150 and tc['chg24'] > 30: tags.append('[PUMP-RISK]')
    if tc['rank'] > 150 and tc['chg24'] < -10: tags.append('[CAPITULATION]')
    tag_str = ' '.join(tags[:2])
    print(f"{i}. {tc['name']} ({tc['symbol']}) — #{tc['rank']}, {fmt_price(tc['price'])}, 24h {tc['chg24']:+.1f}%  {tag_str}")
