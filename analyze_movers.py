#!/usr/bin/env python3
"""Token movers analysis script for aeon skill."""
import json
import urllib.request
import sys

STABLECOIN_IDS = {
    "tether", "usd-coin", "dai", "first-digital-usd", "usde", "tusd", "usdd",
    "pyusd", "fdusd", "paxg", "frax", "true-usd", "usdt", "usdc", "busd",
    "usdn", "rai", "lusd", "nusd", "susd", "usdp", "gusd", "xaut",
    "stasis-eurs", "euro-coin", "ageur"
}
STABLECOIN_SYMBOLS = {"USDT","USDC","BUSD","DAI","FRAX","TUSD","USDP","GUSD","LUSD","SUSD",
                       "RAI","NUSD","USDN","USDE","PYUSD","FDUSD","EURC","EURS","AGEUR","PAXG","XAUT"}

def fmt_price(p):
    if p is None:
        return "N/A"
    if p >= 1000:
        return f"${p:,.0f}"
    elif p >= 1:
        return f"${p:.2f}"
    elif p >= 0.01:
        return f"${p:.4f}"
    else:
        return f"${p:.6f}"

def fmt_vol(v):
    if v is None:
        return "N/A"
    if v >= 1e9:
        return f"${v/1e9:.2f}B"
    elif v >= 1e6:
        return f"${v/1e6:.0f}M"
    else:
        return f"${v/1e3:.0f}K"

def fmt_pct(p):
    if p is None:
        return "N/A"
    sign = "+" if p >= 0 else ""
    return f"{sign}{p:.1f}%"

def is_stablecoin(coin):
    if coin["id"] in STABLECOIN_IDS:
        return True
    sym = (coin.get("symbol") or "").upper()
    if sym in STABLECOIN_SYMBOLS:
        return True
    if sym.startswith("USD") or sym.startswith("EUR") or sym.startswith("GBP"):
        return True
    name = (coin.get("name") or "").lower()
    if "stablecoin" in name:
        return True
    return False

def get_tags(coin, trending_ids, top250_ids):
    tags = []
    rank = coin.get("market_cap_rank") or 9999
    change_24h = coin.get("price_change_percentage_24h_in_currency") or 0
    change_7d = coin.get("price_change_percentage_7d_in_currency") or 0
    change_1h = coin.get("price_change_percentage_1h_in_currency") or 0
    vol = coin.get("total_volume") or 0
    mcap = coin.get("market_cap") or 1
    coin_id = coin["id"]

    is_trending = coin_id in trending_ids
    is_winner = change_24h > 0
    is_loser = change_24h < 0

    if is_trending and is_winner and change_24h > 5:
        tags.append("[TRENDING+UP]")
    elif is_trending and is_loser and change_24h < -5:
        tags.append("[TRENDING+DOWN]")

    if change_24h > 15 and change_7d > 25 and "[TRENDING+UP]" not in tags:
        tags.append("[BREAKOUT]")
    elif change_24h > 20 and change_7d < 0 and "[TRENDING+UP]" not in tags:
        tags.append("[FADE]")

    if change_24h < -10 and (vol / mcap) > 0.25:
        tags.append("[CAPITULATION]")

    if rank > 150 and change_24h > 30:
        tags.append("[PUMP-RISK]")

    if mcap < 50_000_000:
        tags.append("[MICROCAP]")
    elif rank <= 20:
        tags.append("[MAJOR]")

    return tags[:2]

# Fetch markets data
print("Fetching markets data...", file=sys.stderr)
try:
    url = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d"
    req = urllib.request.Request(url, headers={"User-Agent": "aeon-bot/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        markets = json.loads(resp.read())
    print(f"Got {len(markets)} coins from API", file=sys.stderr)
except Exception as e:
    print(f"API fetch failed: {e}, using cached file", file=sys.stderr)
    with open("/home/runner/work/aeon/aeon/cg_markets.json") as f:
        markets = json.load(f)
    print(f"Got {len(markets)} coins from cache", file=sys.stderr)

# Use trending from stdin (passed as second arg or embedded)
trending_data = {
    "trending_coins": [
        {"id":"pipedog","name":"pipedog","symbol":"PIPEDOG","market_cap_rank":682,"price":0.00218,"price_change_percentage_24h_usd":-2.67},
        {"id":"pump-fun","name":"Pump.fun","symbol":"PUMP","market_cap_rank":44,"price":0.00522,"price_change_percentage_24h_usd":12.90},
        {"id":"bitcoin","name":"Bitcoin","symbol":"BTC","market_cap_rank":1,"price":76175,"price_change_percentage_24h_usd":-1.64},
        {"id":"spx6900","name":"SPX6900","symbol":"SPX","market_cap_rank":113,"price":0.436,"price_change_percentage_24h_usd":-1.86},
        {"id":"official-trump","name":"Official Trump","symbol":"TRUMP","market_cap_rank":92,"price":2.47,"price_change_percentage_24h_usd":-17.91},
        {"id":"hyperliquid","name":"Hyperliquid","symbol":"HYPE","market_cap_rank":9,"price":78.64,"price_change_percentage_24h_usd":-1.89},
        {"id":"zcash","name":"Zcash","symbol":"ZEC","market_cap_rank":11,"price":788.87,"price_change_percentage_24h_usd":-1.25},
        {"id":"ethena","name":"Ethena","symbol":"ENA","market_cap_rank":57,"price":0.1524,"price_change_percentage_24h_usd":-0.12},
        {"id":"aligned","name":"Aligned","symbol":"ALIGN","market_cap_rank":711,"price":0.01520,"price_change_percentage_24h_usd":-18.81},
        {"id":"solana","name":"Solana","symbol":"SOL","market_cap_rank":7,"price":92.22,"price_change_percentage_24h_usd":-2.14},
        {"id":"interfold","name":"The Interfold","symbol":"FOLD","market_cap_rank":560,"price":0.1153,"price_change_percentage_24h_usd":25.41},
        {"id":"ripple","name":"XRP","symbol":"XRP","market_cap_rank":5,"price":1.448,"price_change_percentage_24h_usd":-7.33},
        {"id":"lighter","name":"Lighter","symbol":"LIT","market_cap_rank":84,"price":3.099,"price_change_percentage_24h_usd":1.23},
    ]
}

trending_coins = trending_data["trending_coins"][:7]
trending_ids = {c["id"] for c in trending_data["trending_coins"]}

# Filter
filtered = []
for c in markets:
    if is_stablecoin(c):
        continue
    vol = c.get("total_volume") or 0
    if vol < 1_000_000:
        continue
    # Skip wrapped dupes
    sym = (c.get("symbol") or "").lower()
    if sym in {"wbtc","weth","steth","cbbtc","weeth","wsteth","reth","cbeth","ezeth","rseth"}:
        continue
    filtered.append(c)

# Sort for winners/losers
by_24h = sorted(filtered, key=lambda c: c.get("price_change_percentage_24h_in_currency") or 0)
losers = by_24h[:10]
winners = by_24h[-10:][::-1]

# Market pulse
top100 = [c for c in filtered if (c.get("market_cap_rank") or 9999) <= 100]
green_count = sum(1 for c in top100 if (c.get("price_change_percentage_24h_in_currency") or 0) > 0)
top50 = sorted(top100, key=lambda c: c.get("market_cap_rank") or 9999)[:50]
median_50 = sorted([c.get("price_change_percentage_24h_in_currency") or 0 for c in top50])[25]

if green_count < 30:
    pulse = f"Broad risk-off — {green_count}/100 top coins green, median {median_50:+.1f}%; selling pressure across the board."
elif green_count >= 60:
    pulse = f"Risk-on — {green_count}/100 top coins green, median {median_50:+.1f}%; broad participation."
else:
    pulse = f"Mixed tape — {green_count}/100 top coins green, median {median_50:+.1f}%; no clear directional dominance."

# Tag everything
for c in winners + losers:
    c["_tags"] = get_tags(c, trending_ids, set(cc["id"] for cc in filtered))

for tc in trending_coins:
    # Find in markets for tags
    match = next((c for c in filtered if c["id"] == tc["id"]), None)
    if match:
        tc["_tags"] = get_tags(match, trending_ids, set())
    else:
        tc["_tags"] = []

# Build message
today = "2026-08-23"
lines = []
lines.append(f"*Token Movers — {today}*")
lines.append("")
lines.append(f"_{pulse}_")
lines.append("")
lines.append("*Top Winners (24h)*")
for i, c in enumerate(winners, 1):
    name = c["name"]
    sym = c["symbol"].upper()
    price = fmt_price(c.get("current_price"))
    p24 = fmt_pct(c.get("price_change_percentage_24h_in_currency"))
    p7d = fmt_pct(c.get("price_change_percentage_7d_in_currency"))
    p1h = fmt_pct(c.get("price_change_percentage_1h_in_currency"))
    vol = fmt_vol(c.get("total_volume"))
    rank = c.get("market_cap_rank") or "?"
    tags = " ".join(c.get("_tags", []))
    tag_str = f"  {tags}" if tags else ""
    lines.append(f"{i}. {sym} ({name}) — {price}  {p24} / 7d {p7d} / 1h {p1h}  •  {vol} / #{rank}{tag_str}")

lines.append("")
lines.append("*Top Losers (24h)*")
for i, c in enumerate(losers, 1):
    name = c["name"]
    sym = c["symbol"].upper()
    price = fmt_price(c.get("current_price"))
    p24 = fmt_pct(c.get("price_change_percentage_24h_in_currency"))
    p7d = fmt_pct(c.get("price_change_percentage_7d_in_currency"))
    p1h = fmt_pct(c.get("price_change_percentage_1h_in_currency"))
    vol = fmt_vol(c.get("total_volume"))
    rank = c.get("market_cap_rank") or "?"
    tags = " ".join(c.get("_tags", []))
    tag_str = f"  {tags}" if tags else ""
    lines.append(f"{i}. {sym} ({name}) — {price}  {p24} / 7d {p7d} / 1h {p1h}  •  {vol} / #{rank}{tag_str}")

lines.append("")
lines.append("*Trending*")
for i, tc in enumerate(trending_coins, 1):
    name = tc["name"]
    sym = tc["symbol"].upper()
    rank = tc.get("market_cap_rank") or "?"
    price = fmt_price(tc.get("price"))
    p24 = fmt_pct(tc.get("price_change_percentage_24h_usd"))
    tags = " ".join(tc.get("_tags", []))
    tag_str = f"  {tags}" if tags else ""
    lines.append(f"{i}. {name} ({sym}) — #{rank}, {price}, 24h {p24}{tag_str}")

# Notable section
notable = []
for c in winners + losers:
    tags = c.get("_tags", [])
    sym = c["symbol"].upper()
    p24 = c.get("price_change_percentage_24h_in_currency") or 0
    vol = c.get("total_volume") or 0
    mcap = c.get("market_cap") or 1
    rank = c.get("market_cap_rank") or "?"
    if "[TRENDING+UP]" in tags:
        notable.append(f"• {sym}: trending + up {p24:+.1f}% — strong dual signal")
    if "[BREAKOUT]" in tags:
        notable.append(f"• {sym}: [BREAKOUT] {p24:+.1f}% 24h sustained over multi-day move")
    if "[CAPITULATION]" in tags:
        notable.append(f"• {sym}: [CAPITULATION] {p24:.1f}% on elevated volume (vol/mcap {vol/mcap:.2f})")
    if "[PUMP-RISK]" in tags:
        notable.append(f"• {sym}: #{rank} up {p24:+.1f}% — [PUMP-RISK] low-cap, manipulation likely")

for tc in trending_coins:
    tags = tc.get("_tags", [])
    sym = tc["symbol"].upper()
    p24 = tc.get("price_change_percentage_24h_usd") or 0
    rank = tc.get("market_cap_rank") or "?"
    if "[PUMP-RISK]" in tags:
        notable.append(f"• {sym}: #{rank} trending + up {p24:+.1f}% — [PUMP-RISK]")

# Deduplicate notable
seen_notable = set()
notable_deduped = []
for n in notable:
    sym = n.split(":")[0].replace("•","").strip()
    if sym not in seen_notable:
        seen_notable.add(sym)
        notable_deduped.append(n)

if notable_deduped:
    lines.append("")
    lines.append("*Notable*")
    for n in notable_deduped[:4]:
        lines.append(n)

msg = "\n".join(lines)
# Trim if over 4000 chars
if len(msg) > 4000:
    # Shrink to top 7 winners/losers
    lines2 = []
    lines2.append(f"*Token Movers — {today}*")
    lines2.append("")
    lines2.append(f"_{pulse}_")
    lines2.append("")
    lines2.append("*Top Winners (24h)*")
    for i, c in enumerate(winners[:7], 1):
        sym = c["symbol"].upper()
        price = fmt_price(c.get("current_price"))
        p24 = fmt_pct(c.get("price_change_percentage_24h_in_currency"))
        p7d = fmt_pct(c.get("price_change_percentage_7d_in_currency"))
        vol = fmt_vol(c.get("total_volume"))
        rank = c.get("market_cap_rank") or "?"
        tags = " ".join(c.get("_tags", []))
        tag_str = f"  {tags}" if tags else ""
        lines2.append(f"{i}. {sym} — {price}  {p24} / 7d {p7d}  •  {vol} / #{rank}{tag_str}")
    lines2.append("")
    lines2.append("*Top Losers (24h)*")
    for i, c in enumerate(losers[:7], 1):
        sym = c["symbol"].upper()
        price = fmt_price(c.get("current_price"))
        p24 = fmt_pct(c.get("price_change_percentage_24h_in_currency"))
        p7d = fmt_pct(c.get("price_change_percentage_7d_in_currency"))
        vol = fmt_vol(c.get("total_volume"))
        rank = c.get("market_cap_rank") or "?"
        tags = " ".join(c.get("_tags", []))
        tag_str = f"  {tags}" if tags else ""
        lines2.append(f"{i}. {sym} — {price}  {p24} / 7d {p7d}  •  {vol} / #{rank}{tag_str}")
    lines2.append("")
    lines2.append("*Trending*")
    for i, tc in enumerate(trending_coins[:5], 1):
        sym = tc["symbol"].upper()
        rank = tc.get("market_cap_rank") or "?"
        price = fmt_price(tc.get("price"))
        p24 = fmt_pct(tc.get("price_change_percentage_24h_usd"))
        tags = " ".join(tc.get("_tags", []))
        tag_str = f"  {tags}" if tags else ""
        lines2.append(f"{i}. {sym} — #{rank}, {price}, 24h {p24}{tag_str}")
    if notable_deduped:
        lines2.append("")
        lines2.append("*Notable*")
        for n in notable_deduped[:3]:
            lines2.append(n)
    msg = "\n".join(lines2)

print(msg)

# Print log data to stderr
print("---LOG---", file=sys.stderr)
w_syms = ", ".join(f"{c['symbol'].upper()} ({fmt_pct(c.get('price_change_percentage_24h_in_currency'))})" for c in winners[:5])
l_syms = ", ".join(f"{c['symbol'].upper()} ({fmt_pct(c.get('price_change_percentage_24h_in_currency'))})" for c in losers[:5])
t_syms = ", ".join(tc["symbol"].upper() for tc in trending_coins[:5])
notable_log = ", ".join(seen_notable) if seen_notable else "none"
print(f"PULSE:{pulse}", file=sys.stderr)
print(f"WINNERS:{w_syms}", file=sys.stderr)
print(f"LOSERS:{l_syms}", file=sys.stderr)
print(f"TRENDING:{t_syms}", file=sys.stderr)
print(f"NOTABLE:{notable_log}", file=sys.stderr)
