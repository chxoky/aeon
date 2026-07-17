def stable_ids: ["tether","usd-coin","dai","first-digital-usd","usde","tusd","usdd","pyusd","fdusd","paxg","ethena-usde","binance-peg-busd","blackrock-usd-institutional-digital-liquidity-fund","ondo-us-dollar-yield","usds","sky-dollar","ripple-usd","rlusd","global-dollar","usd1-world-liberty-financial","paxos-gold","tether-gold","susds"];
def wrapped: ["wbtc","weth","steth","wsteth","weeth","reth","cbbtc","wbeth","lbtc","solvbtc","binance-bridged-usdt-bnb-smart-chain","coinbase-wrapped-btc","rseth","meth","msol","jitosol","bsc-usd","usdt0","binance-bridged-usdc-bnb-smart-chain","rocket-pool-eth","kelp-dao-restaked-eth","clbtc"];

map(select(
  (.price_change_percentage_24h_in_currency != null)
  and ((.total_volume // 0) >= 1000000)
  and (([.id] | inside(stable_ids)) | not)
  and (([.id] | inside(wrapped)) | not)
  and ((.symbol|ascii_downcase|startswith("usd")) | not)
  and ((.symbol|ascii_downcase|startswith("eur")) | not)
  and ((.name|ascii_downcase|contains("stablecoin")) | not)
))
