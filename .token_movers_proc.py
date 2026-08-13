import json, sys

data = json.load(sys.stdin)

stablecoins = {
    'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd',
    'fdusd','paxg','wbtc','weth','steth','wrapped-bitcoin','wrapped-ethereum',
    'ethena-usde','usds','susds','sky','binance-peg-weth','lido-staked-ether'
}

def is_stable(c):
    if c['id'] in stablecoins:
        return True
    sym = c['symbol'].upper()
    name = c['name'].upper()
    if sym.startswith(('USD','EUR','GBP')):
        return True
    if 'STABLECOIN' in name:
        return True
    return False

filtered = [c for c in data if not is_stable(c) and (c.get('total_volume') or 0) > 1_000_000]

# Market pulse
top100 = [c for c in filtered if (c.get('market_cap_rank') or 999) <= 100]
green = sum(1 for c in top100 if (c.get('price_change_percentage_24h') or 0) > 0)
chg50 = sorted([(c.get('price_change_percentage_24h') or 0) for c in filtered if (c.get('market_cap_rank') or 999) <= 50])
median50 = chg50[len(chg50)//2] if chg50 else 0
print(f"PULSE|{green}|{len(top100)}|{median50:.1f}")

sorted_24h = sorted(filtered, key=lambda c: c.get('price_change_percentage_24h') or 0, reverse=True)

def fmt_coin(c):
    rank = c.get('market_cap_rank','?')
    sym = c['symbol'].upper()
    name = c['name']
    price = c.get('current_price') or 0
    ch24 = c.get('price_change_percentage_24h') or 0
    ch7d = c.get('price_change_percentage_7d_in_currency') or 0
    ch1h = c.get('price_change_percentage_1h_in_currency') or 0
    vol = c.get('total_volume') or 0
    mcap = c.get('market_cap') or 0
    vol_str = f"${vol/1e9:.2f}B" if vol >= 1e9 else f"${vol/1e6:.0f}M"
    mcap_str = f"${mcap/1e9:.2f}B" if mcap >= 1e9 else f"${mcap/1e6:.0f}M"
    # tags
    tags = []
    if (c.get('market_cap_rank') or 999) <= 20:
        tags.append('MAJOR')
    if (c.get('market_cap_rank') or 999) > 150 and ch24 > 30:
        tags.append('PUMP-RISK')
    if mcap < 50_000_000:
        tags.append('MICROCAP')
    if ch24 > 15 and ch7d > 25:
        tags.append('BREAKOUT')
    if ch24 > 20 and ch7d < 0:
        tags.append('FADE')
    if ch24 < -10 and vol > 0 and mcap > 0 and (vol/mcap) > 0.25:
        tags.append('CAPITULATION')
    tag_str = ' '.join(f'[{t}]' for t in tags[:2])
    return f"{sym}|{name}|{rank}|{price}|{ch24:.1f}|{ch7d:.1f}|{ch1h:.1f}|{vol_str}|{mcap_str}|{tag_str}"

print("WINNERS")
for c in sorted_24h[:10]:
    print(fmt_coin(c))

print("LOSERS")
for c in sorted_24h[-10:]:
    print(fmt_coin(c))

# IDs for trending cross-ref
print("IDS")
for c in filtered:
    print(f"{c['id']}|{c['symbol'].upper()}|{c.get('price_change_percentage_24h') or 0:.1f}")
