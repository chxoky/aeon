const fs = require('fs');

const markets = JSON.parse(fs.readFileSync('./cg_markets.json', 'utf8'));
const trendingData = JSON.parse(fs.readFileSync('./cg_trending.json', 'utf8'));

const STABLECOIN_IDS = new Set([
  'tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd',
  'fdusd','paxg','frax','true-usd','usds','ethena-usde','binance-peg-busd',
  'binance-usd','usdb','usdx','usdr','cusd','usdbr'
]);

const WRAPPED_DUPES = new Set(['wbtc','weth','steth','wsteth','weeth','reth','cbeth','bwbtc','ezeth']);

function isStable(c) {
  if (STABLECOIN_IDS.has(c.id)) return true;
  const sym = c.symbol.toUpperCase();
  if (sym.startsWith('USD') || sym.startsWith('EUR') || sym.startsWith('GBP')) return true;
  if (c.name.toLowerCase().includes('stablecoin')) return true;
  const price = c.current_price || 0;
  const chg = Math.abs(c.price_change_percentage_24h_in_currency || 0);
  if (price >= 0.97 && price <= 1.03 && chg < 0.5) return true;
  return false;
}

const get24h = c => c.price_change_percentage_24h_in_currency || c.price_change_percentage_24h || 0;
const get7d = c => c.price_change_percentage_7d_in_currency || 0;
const get1h = c => c.price_change_percentage_1h_in_currency || 0;

const filtered = markets.filter(c =>
  !isStable(c) &&
  !WRAPPED_DUPES.has(c.id) &&
  (c.total_volume || 0) >= 1_000_000
);

const sorted = [...filtered].sort((a, b) => get24h(b) - get24h(a));
const winners = sorted.slice(0, 10);
const losers = sorted.slice(-10).reverse();

const top100 = filtered.slice(0, 100);
const nGreen = top100.filter(c => get24h(c) > 0).length;
const top50Changes = filtered.slice(0, 50).map(c => get24h(c)).sort((a, b) => a - b);
const median50 = top50Changes[25] || 0;

const trendingCoins = (trendingData.coins || []).slice(0, 7).map(item => {
  const d = item.item;
  const priceChangeDict = d.data?.price_change_percentage_24h;
  const ch24 = typeof priceChangeDict === 'object' ? (priceChangeDict.usd || 0) : 0;
  return {
    name: d.name,
    symbol: d.symbol.toUpperCase(),
    rank: d.market_cap_rank || 'N/A',
    price: d.data?.price || 0,
    ch24,
    id: d.id
  };
});

const trendingIds = new Set(trendingCoins.map(t => t.id));
const trendingSyms = new Set(trendingCoins.map(t => t.symbol));

function tagCoin(c, isTrending) {
  const c24 = get24h(c);
  const c7d = get7d(c);
  const vol = c.total_volume || 0;
  const mcap = c.market_cap || 1;
  const rank = c.market_cap_rank || 999;
  const tags = [];

  if (isTrending && c24 > 0) tags.push('[TRENDING+UP]');
  else if (isTrending && c24 < 0) tags.push('[TRENDING+DOWN]');

  if (c24 > 15 && c7d > 25) tags.push('[BREAKOUT]');
  if (c24 > 20 && c7d < 0) tags.push('[FADE]');
  if (c24 < -10 && (vol / mcap) > 0.25) tags.push('[CAPITULATION]');
  if (rank > 150 && c24 > 30) tags.push('[PUMP-RISK]');
  if (mcap < 50_000_000) tags.push('[MICROCAP]');
  if (rank <= 20) tags.push('[MAJOR]');

  return tags.slice(0, 2);
}

function fmtPrice(p) {
  if (!p) return 'N/A';
  if (p >= 1000) return '$' + p.toLocaleString('en', {maximumFractionDigits: 0});
  if (p >= 1) return '$' + p.toFixed(3);
  if (p >= 0.01) return '$' + p.toFixed(4);
  return '$' + p.toFixed(6);
}

function fmtVol(v) {
  if (!v) return 'N/A';
  if (v >= 1e9) return '$' + (v/1e9).toFixed(1) + 'B';
  if (v >= 1e6) return '$' + Math.round(v/1e6) + 'M';
  return '$' + v.toLocaleString();
}

console.log(`Filtered: ${filtered.length} coins`);
console.log(`Market pulse: ${nGreen}/100 green, median top-50: ${median50.toFixed(1)}%`);
console.log('');

console.log('=== WINNERS ===');
winners.forEach((c, i) => {
  const isT = trendingIds.has(c.id) || trendingSyms.has(c.symbol.toUpperCase());
  const tags = tagCoin(c, isT);
  const ch24 = get24h(c);
  const ch7d = get7d(c);
  const ch1h = get1h(c);
  console.log(`${i+1}. ${c.symbol.toUpperCase()} (${c.name}) — ${fmtPrice(c.current_price)}  ${ch24.toFixed(1)}% / 7d ${ch7d.toFixed(1)}% / 1h ${ch1h.toFixed(1)}%  • ${fmtVol(c.total_volume)} / #${c.market_cap_rank}  ${tags.join(' ')}`);
});

console.log('');
console.log('=== LOSERS ===');
losers.forEach((c, i) => {
  const isT = trendingIds.has(c.id) || trendingSyms.has(c.symbol.toUpperCase());
  const tags = tagCoin(c, isT);
  const ch24 = get24h(c);
  const ch7d = get7d(c);
  const ch1h = get1h(c);
  console.log(`${i+1}. ${c.symbol.toUpperCase()} (${c.name}) — ${fmtPrice(c.current_price)}  ${ch24.toFixed(1)}% / 7d ${ch7d.toFixed(1)}% / 1h ${ch1h.toFixed(1)}%  • ${fmtVol(c.total_volume)} / #${c.market_cap_rank}  ${tags.join(' ')}`);
});

console.log('');
console.log('=== TRENDING ===');
trendingCoins.forEach((t, i) => {
  const isWinner = winners.some(c => c.symbol.toUpperCase() === t.symbol);
  const isLoser = losers.some(c => c.symbol.toUpperCase() === t.symbol);
  const tag = t.ch24 > 0 ? '[TRENDING+UP]' : '[TRENDING+DOWN]';
  const inList = isWinner ? ' (in winners)' : isLoser ? ' (in losers)' : '';
  console.log(`${i+1}. ${t.name} (${t.symbol}) — #${t.rank}, ${fmtPrice(t.price)}, 24h ${t.ch24.toFixed(1)}%  ${tag}${inList}`);
});

console.log('');
console.log('=== NOTABLE ===');
const notable = [];
[...winners, ...losers].forEach(c => {
  const isT = trendingIds.has(c.id) || trendingSyms.has(c.symbol.toUpperCase());
  const tags = tagCoin(c, isT);
  const ch24 = get24h(c);
  const ch7d = get7d(c);
  const vol = c.total_volume || 0;
  const mcap = c.market_cap || 1;
  const vmcap = vol / mcap;
  if (tags.some(t => ['[TRENDING+UP]','[BREAKOUT]','[CAPITULATION]','[PUMP-RISK]'].includes(t))) {
    notable.push({sym: c.symbol.toUpperCase(), name: c.name, tags, ch24, ch7d, vol, mcap, rank: c.market_cap_rank, vmcap});
  }
});

const seen = new Set();
notable.filter(n => {
  if (seen.has(n.sym)) return false;
  seen.add(n.sym);
  return true;
}).forEach(n => {
  console.log(`${n.sym} (${n.name}) ${n.tags.join(' ')} #${n.rank} 24h=${n.ch24.toFixed(1)}% 7d=${n.ch7d.toFixed(1)}% vol/mcap=${n.vmcap.toFixed(2)}`);
});
