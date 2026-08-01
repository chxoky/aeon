def is_stable:
  .id as $id | .symbol as $sym | .name as $name |
  (["tether","usd-coin","dai","first-digital-usd","usde","tusd","usdd","pyusd","fdusd","paxg","binance-usd","gemini-dollar","frax","terrausd","wrapped-bitcoin","tether-eurt","stasis-eurs","celo-dollar","true-usd","neutrino"] | contains([$id])) or
  (($sym | ascii_downcase) | startswith("usd")) or
  (($sym | ascii_downcase) | startswith("eur")) or
  (($sym | ascii_downcase) | startswith("gbp")) or
  (($name | ascii_downcase) | contains("stablecoin"));

def is_illiquid: (.total_volume // 0) < 1000000;

[.[] | select(is_stable | not) | select(is_illiquid | not) | select((.market_cap_rank // 999) <= 100)] |
{
  total: length,
  green: [.[] | select(.price_change_percentage_24h > 0)] | length,
  median_index: (length / 2 | floor),
  top50_sorted: (sort_by(.market_cap_rank // 999)[0:50] | [.[].price_change_percentage_24h // 0] | sort)
}
