def stable:
  (.id as $id | ["tether","usd-coin","dai","first-digital-usd","usde","tusd","usdd","pyusd","fdusd","paxg","ethena-usde","binance-usd","frax","usdt","staked-usde","usds","sky-dollar","usd0","usdb","crvusd","gho","ethena-staked-usde","usdt0","buidl"] | index($id) != null)
  or ((.symbol|ascii_upcase) | (startswith("USD") or startswith("EUR") or startswith("GBP")))
  or ((.name|ascii_downcase) | contains("stablecoin"));

def d24: (.price_change_percentage_24h_in_currency // 0);
def d7:  (.price_change_percentage_7d_in_currency // 0);
def d1:  (.price_change_percentage_1h_in_currency // 0);

[ .[] | select((stable|not) and (.total_volume // 0) >= 1000000 and (.price_change_percentage_24h_in_currency != null)) ] as $f
| {
    winners: [ ($f | sort_by(d24) | reverse | .[0:10])[] | {sym:(.symbol|ascii_upcase), name, price:.current_price, d24:d24, d7:d7, d1:d1, vol:.total_volume, rank:.market_cap_rank, mcap:.market_cap} ],
    losers:  [ ($f | sort_by(d24) | .[0:10])[] | {sym:(.symbol|ascii_upcase), name, price:.current_price, d24:d24, d7:d7, d1:d1, vol:.total_volume, rank:.market_cap_rank, mcap:.market_cap} ],
    green: ([ ($f | sort_by(.market_cap_rank // 9999) | .[0:100])[] | select(d24 > 0) ] | length),
    top100n: ([ $f | sort_by(.market_cap_rank // 9999) | .[0:100] ][0] | length),
    median: ([ ($f | sort_by(.market_cap_rank // 9999) | .[0:50])[] | d24 ] | sort | .[ (length/2|floor) ]),
    btc: ($f | map(select(.id=="bitcoin"))[0] | {price:.current_price, d24:d24, d7:d7}),
    eth: ($f | map(select(.id=="ethereum"))[0] | {price:.current_price, d24:d24, d7:d7})
  }
