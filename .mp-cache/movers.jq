def stableids: ["tether","usd-coin","dai","first-digital-usd","usde","tusd","usdd","pyusd","fdusd","paxg","ethena-usde","usds","sky-dollar","binance-usd","true-usd","ripple-usd","usdt0","ethena-staked-usde","coinbase-wrapped-btc","wrapped-steth","wrapped-eeth","binance-staked-sol","jito-staked-sol","lombard-staked-btc","wrapped-beacon-eth","susds","blackrock-usd-institutional-digital-liquidity-fund","weeth"];
def isstable: (.id as $id | (stableids | index($id)) != null)
  or (.symbol|ascii_upcase| (startswith("USD") or startswith("EUR") or startswith("GBP")))
  or (.name|ascii_downcase| (contains("stablecoin") or contains("staked ether") or contains("wrapped ") or startswith("wrapped") or contains("staked sol") or contains("staked btc")));
def c24: (.price_change_percentage_24h_in_currency // .price_change_percentage_24h // 0);
def c7: (.price_change_percentage_7d_in_currency // 0);
def c1: (.price_change_percentage_1h_in_currency // 0);
def row: "\(.symbol|ascii_upcase) (\(.name)) | $\(.current_price) | 24h \(c24|.*10|round/10)% 7d \(c7|.*10|round/10)% 1h \(c1|.*10|round/10)% | vol \(.total_volume) mc \(.market_cap) #\(.market_cap_rank)";
[ .[] | select(isstable|not) | select((.total_volume // 0) >= 1000000) ] as $f
| "===WINNERS===",
  ( $f | sort_by(c24) | reverse | .[0:10][] | row ),
  "===LOSERS===",
  ( $f | sort_by(c24) | .[0:10][] | row ),
  "===PULSE===",
  ( ($f[0:100] | map(select(c24>0)) | length) as $g100
    | ($f[0:50] | map(c24) | sort | .[25]) as $med
    | "top100 green \($g100)/100  median-top50-24h \($med|.*100|round/100)%" ),
  "===BREADTH-top20===",
  ( ( .[0:20] | map(select(c24>0)) | length ) as $b24
    | ( .[0:20] | map(select(c7>0)) | length ) as $b7
    | "\($b24)/20 green 24h  \($b7)/20 green 7d" ),
  "===MAJORS===",
  ( .[] | select(.id=="bitcoin" or .id=="ethereum" or .id=="solana")
    | "\(.id): $\(.current_price) 24h \(c24|.*100|round/100)% 7d \(c7|.*100|round/100)% mc \(.market_cap)" )
