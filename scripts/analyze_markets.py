import json, sys

data = json.load(sys.stdin)

stablecoins = {
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd',
    'fdusd','paxg','binance-usd','true-usd','paypal-usd','ethena-usde',
    'frax','liquity-usd','usds','usual-usd','sky-usd'
}
stablecoin_syms = {'USDT','USDC','BUSD','TUSD','USDP','EURS','EURT','USDD','FDUSD','PYUSD','USDE'}
wrapped = {'wrapped-bitcoin','wrapped-ether','staked-ether','wrapped-steth','wrapped-eeth','rocket-pool-eth','coinbase-wrapped-staked-eth','lido-staked-ether'}

def fmt_price(p):
    if p is None:
        return '?'
    if p >= 1000:
        return f'${p:,.0f}'
    elif p >= 1:
        return f'${p:.4g}'
    elif p >= 0.01:
        return f'${p:.4f}'
    else:
        return f'${p:.6f}'

def fmt_vol(v):
    if v >= 1e9:
        return f'${v/1e9:.2f}B'
    elif v >= 1e6:
        return f'${v/1e6:.0f}M'
    else:
        return f'${v/1e3:.0f}K'

def fmt_mcap(v):
    if v >= 1e9:
        return f'${v/1e9:.1f}B'
    elif v >= 1e6:
        return f'${v/1e6:.0f}M'
    else:
        return f'${v/1e3:.0f}K'

filtered = []
for c in data:
    if c['id'] in stablecoins:
        continue
    if c['id'] in wrapped:
        continue
    sym = (c.get('symbol') or '').upper()
    if sym in stablecoin_syms:
        continue
    if sym.startswith(('USD','EUR','GBP')):
        continue
    name_lower = (c.get('name') or '').lower()
    if 'stablecoin' in name_lower:
        continue
    vol = c.get('total_volume') or 0
    if vol < 1_000_000:
        continue
    filtered.append(c)

print(f"# STATS: total={len(data)}, filtered={len(filtered)}", flush=True)

# Top 10 winners
valid = [c for c in filtered if c.get('price_change_percentage_24h') is not None]
winners = sorted(valid, key=lambda x: x['price_change_percentage_24h'], reverse=True)[:10]
print("\n=== TOP WINNERS ===")
for c in winners:
    p24 = c.get('price_change_percentage_24h') or 0
    p7d = c.get('price_change_percentage_7d_in_currency') or 0
    p1h = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 999
    price = c.get('current_price') or 0
    sym = c.get('symbol','?').upper()
    name = c.get('name','?')
    # Tags
    tags = []
    if rank <= 20:
        tags.append('[MAJOR]')
    if rank > 150 and p24 > 30:
        tags.append('[PUMP-RISK]')
    if p24 > 15 and p7d > 25:
        tags.append('[BREAKOUT]')
    elif p24 > 20 and p7d < 0:
        tags.append('[FADE]')
    if mcap < 50_000_000:
        tags.append('[MICROCAP]')
    tag_str = ' '.join(tags[:2])
    print(f"  {sym}|{name}|rank={rank}|{fmt_price(price)}|24h={p24:.1f}%|7d={p7d:.1f}%|1h={p1h:.1f}%|{fmt_vol(vol)}|{fmt_mcap(mcap)}|{tag_str}")

# Top 10 losers
losers = sorted(valid, key=lambda x: x['price_change_percentage_24h'])[:10]
print("\n=== TOP LOSERS ===")
for c in losers:
    p24 = c.get('price_change_percentage_24h') or 0
    p7d = c.get('price_change_percentage_7d_in_currency') or 0
    p1h = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    rank = c.get('market_cap_rank') or 999
    price = c.get('current_price') or 0
    sym = c.get('symbol','?').upper()
    name = c.get('name','?')
    tags = []
    if rank <= 20:
        tags.append('[MAJOR]')
    if p24 < -10 and vol / mcap > 0.25 if mcap > 0 else False:
        tags.append('[CAPITULATION]')
    if mcap < 50_000_000:
        tags.append('[MICROCAP]')
    tag_str = ' '.join(tags[:2])
    print(f"  {sym}|{name}|rank={rank}|{fmt_price(price)}|24h={p24:.1f}%|7d={p7d:.1f}%|1h={p1h:.1f}%|{fmt_vol(vol)}|{fmt_mcap(mcap)}|{tag_str}")

# Market pulse
top100 = filtered[:100]
green = sum(1 for c in top100 if (c.get('price_change_percentage_24h') or 0) > 0)
changes_50 = sorted([c.get('price_change_percentage_24h') or 0 for c in top100[:50]])
median_50 = changes_50[25] if len(changes_50) > 25 else changes_50[len(changes_50)//2] if changes_50 else 0
print(f"\n=== MARKET PULSE ===")
print(f"green={green}/100, median_50={median_50:.2f}%")

# Print all symbols for trending cross-check
print("\n=== ALL SYMBOLS ===")
for c in filtered:
    sym = c.get('symbol','?').upper()
    rank = c.get('market_cap_rank') or 999
    p24 = c.get('price_change_percentage_24h') or 0
    print(f"{sym}|{rank}|{p24:.1f}")
