def stable:
  (.id|ascii_downcase) as $id
  | (.symbol|ascii_upcase) as $sym
  | (.name|ascii_downcase) as $nm
  | ([ "tether","usd-coin","dai","first-digital-usd","usde","tusd","usdd","pyusd","fdusd","paxg","ethena-usde","binance-usd","usds","usd0","crvusd","gho","frax","lusd","ethena-staked-usde","sky-dollar" ] | index($id)) != null
    or ($sym|startswith("USD")) or ($sym|startswith("EUR")) or ($sym|startswith("GBP"))
    or ($nm|test("stablecoin"));

def wrapped:
  (.id|ascii_downcase) as $id
  | ([ "wbtc","weth","steth","wsteth","weeth","wbeth","reth","cbbtc","lbtc","bsc-usd","coinbase-wrapped-btc","wrapped-steth","wrapped-bitcoin","staked-ether","rocket-pool-eth","binance-peg-weth","wrapped-eeth","wrapped-beacon-eth","kelp-dao-restaked-eth" ] | index($id)) != null;

def n($k): (.[$k] // 0) | if type=="number" then . else 0 end;

[ .[] | select((stable|not) and (wrapped|not) and ((.total_volume // 0) >= 1000000)) ]
