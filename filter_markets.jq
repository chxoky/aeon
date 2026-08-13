
[.[] | select(
  .id != "tether" and .id != "usd-coin" and .id != "dai" and .id != "first-digital-usd" and
  .id != "usde" and .id != "tusd" and .id != "usdd" and .id != "pyusd" and .id != "fdusd" and
  .id != "paxg" and .id != "frax" and .id != "true-usd" and .id != "usds" and .id != "ethena-usde" and
  .id != "wbtc" and .id != "weth" and .id != "steth" and .id != "wsteth" and .id != "weeth" and
  .id != "reth" and .id != "cbeth" and .id != "ezeth" and
  (.total_volume // 0) >= 1000000 and
  ((.symbol | ascii_upcase | startswith("USD")) | not) and
  ((.symbol | ascii_upcase | startswith("EUR")) | not) and
  ((.symbol | ascii_upcase | startswith("GBP")) | not) and
  ((.name | ascii_downcase | contains("stablecoin")) | not)
)] as $filtered |
$filtered | sort_by(.price_change_percentage_24h_in_currency // 0) | reverse as $sorted |
{
  total: ($filtered | length),
  n_green_top100: ([$filtered[0:100][] | select((.price_change_percentage_24h_in_currency // 0) > 0)] | length),
  winners: [$sorted[0:10][] | {
    sym: (.symbol | ascii_upcase),
    name: .name,
    price: .current_price,
    rank: .market_cap_rank,
    ch24: (.price_change_percentage_24h_in_currency // 0),
    ch7d: (.price_change_percentage_7d_in_currency // 0),
    ch1h: (.price_change_percentage_1h_in_currency // 0),
    vol: (.total_volume // 0),
    mcap: (.market_cap // 0),
    id: .id
  }],
  losers: [($sorted | reverse[0:10])[] | {
    sym: (.symbol | ascii_upcase),
    name: .name,
    price: .current_price,
    rank: .market_cap_rank,
    ch24: (.price_change_percentage_24h_in_currency // 0),
    ch7d: (.price_change_percentage_7d_in_currency // 0),
    ch1h: (.price_change_percentage_1h_in_currency // 0),
    vol: (.total_volume // 0),
    mcap: (.market_cap // 0),
    id: .id
  }]
}
