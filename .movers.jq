def stableids: ["tether","usd-coin","dai","first-digital-usd","usde","ethena-usde","tusd","true-usd","usdd","pyusd","paypal-usd","fdusd","paxos-standard","paxg","pax-gold","usds","sky-dollar","binance-usd","usdc","frax","lusd","gho","crvusd","usd0","usdx","susds","buidl","usdt0","ethena-staked-usde","staked-usde","usual-usd","resolv-usd","falcon-finance","ripple-usd","rlusd","global-dollar","usdg"];
def isstable:
  (.id as $id | (stableids | index($id)) != null)
  or (.symbol|ascii_upcase|startswith("USD"))
  or (.symbol|ascii_upcase|startswith("EUR"))
  or (.symbol|ascii_upcase|startswith("GBP"))
  or (.name|ascii_downcase|contains("stablecoin"));
[ .[]
  | select(isstable|not)
  | select((.total_volume // 0) >= 1000000)
  | select(.price_change_percentage_24h_in_currency != null)
  | {s:(.symbol|ascii_upcase), id, n:.name, r:.market_cap_rank, p:.current_price, v:.total_volume, mc:.market_cap,
     d1:.price_change_percentage_1h_in_currency, d24:.price_change_percentage_24h_in_currency, d7:.price_change_percentage_7d_in_currency}
]
