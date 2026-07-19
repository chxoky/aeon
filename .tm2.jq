def stableids: ["tether","usd-coin","dai","first-digital-usd","usde","ethena-usde","tusd","true-usd","usdd","pyusd","paypal-usd","fdusd","paxg","pax-gold","binance-usd","frax","usdc","gemini-dollar","usds","sky-dollar","ripple-usd","rlusd","ondo-us-dollar-yield","blackrock-usd-institutional-digital-liquidity-fund"];
def isstable:
  (.id|ascii_downcase) as $id
  | (.symbol|ascii_upcase) as $sym
  | (.name|ascii_downcase) as $nm
  | ((stableids|index($id))!=null)
    or ($sym|startswith("USD")) or ($sym|startswith("EUR")) or ($sym|startswith("GBP"))
    or ($nm|test("stablecoin"));
def wrap: {"wbtc":"btc","weth":"eth","steth":"eth","wsteth":"eth","wbeth":"eth","reth":"eth","cbbtc":"btc","lbtc":"btc","weeth":"eth","beth":"eth","wbnb":"bnb","jupsol":"sol","jitosol":"sol","msol":"sol","bnsol":"sol","clbtc":"btc","solvbtc":"btc"};

[ .[]
  | select(isstable|not)
  | select((.total_volume // 0) >= 1000000)
  | select(.price_change_percentage_24h != null)
] as $f
| ($f | sort_by(.market_cap_rank // 9999)
    | reduce .[] as $c ({seen:{}, out:[]};
        (wrap[($c.symbol|ascii_downcase)]) as $u
        | if $u == null then {seen:.seen, out:(.out + [$c])}
          elif (.seen[$u] == true) then .
          else {seen:(.seen + {($u):true}), out:(.out + [$c])} end)
    | .out) as $ff
| ($ff | sort_by(.price_change_percentage_24h)) as $by24
| ($by24[-10:] | reverse) as $winners
| ($by24[0:10]) as $losers
| ($ff | sort_by(.market_cap_rank // 9999) | .[0:100]) as $top100
| ($top100 | map(select((.price_change_percentage_24h // 0) > 0)) | length) as $green
| ($top100[0:50] | map(.price_change_percentage_24h // 0) | sort) as $m50
| {
    pulse: {green: $green, total: ($top100|length), median50: ($m50[($m50|length/2|floor)])},
    winners: ($winners | map({sym:(.symbol|ascii_upcase), name:.name, rank:.market_cap_rank, price:.current_price, ch24:.price_change_percentage_24h, ch7:.price_change_percentage_7d_in_currency, ch1:.price_change_percentage_1h_in_currency, vol:.total_volume, mcap:.market_cap})),
    losers: ($losers | map({sym:(.symbol|ascii_upcase), name:.name, rank:.market_cap_rank, price:.current_price, ch24:.price_change_percentage_24h, ch7:.price_change_percentage_7d_in_currency, ch1:.price_change_percentage_1h_in_currency, vol:.total_volume, mcap:.market_cap}))
  }
