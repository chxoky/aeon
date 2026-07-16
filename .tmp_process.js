const fs = require('fs');
const m = JSON.parse(fs.readFileSync('.tmp_markets.json','utf8'));
const tr = JSON.parse(fs.readFileSync('.tmp_trending.json','utf8'));

const STABLE_IDS = new Set(['tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd',
  'pyusd','fdusd','paxg','ethena-usde','binance-usd','frax','usdb','gho','crvusd','susd','lusd',
  'usdx','usd1','ripple-usd','usds','tether-gold','global-dollar','falcon-finance-usdf',
  'blackrock-usd-institutional-digital-liquidity-fund','ondo-us-dollar-yield']);

function isStable(c){
  const cid=c.id||'', sym=(c.symbol||'').toUpperCase(), name=(c.name||'').toLowerCase();
  if(STABLE_IDS.has(cid)) return true;
  if(sym.startsWith('USD')||sym.startsWith('EUR')||sym.startsWith('GBP')) return true;
  if(name.includes('stablecoin')) return true;
  return false;
}
const WRAPPED=new Set(['wbtc','weth','steth','wsteth','weeth','wbeth','reth','cbbtc','lbtc',
  'solvbtc','msol','jitosol','rseth','ezeth','bsc-usd']);

const g=(c,k)=> (c[k]==null?0:c[k]);
let rows=[];
for(const c of m){
  if(isStable(c)) continue;
  const sym=(c.symbol||'').toLowerCase();
  if((c.total_volume||0)<1_000_000) continue;
  if(WRAPPED.has(sym)) continue;
  rows.push(c);
}
const top100=rows.slice(0,100);
const green=top100.filter(c=>g(c,'price_change_percentage_24h')>0).length;
const top50=rows.slice(0,50).map(c=>g(c,'price_change_percentage_24h')).sort((a,b)=>a-b);
const n=top50.length;
const median50 = n%2 ? top50[(n-1)/2] : (top50[n/2-1]+top50[n/2])/2;
console.log(`PULSE green ${green}/${top100.length} median_top50 ${median50.toFixed(2)} filtered=${rows.length}`);
for(const c of rows){ if(c.id==='bitcoin'||c.id==='ethereum'||c.id==='solana')
  console.log(`${c.symbol.toUpperCase()} px=${g(c,'current_price')} 24h=${g(c,'price_change_percentage_24h').toFixed(2)} 7d=${g(c,'price_change_percentage_7d_in_currency').toFixed(2)} 1h=${g(c,'price_change_percentage_1h_in_currency').toFixed(2)}`);}

const winners=[...rows].sort((a,b)=>g(b,'price_change_percentage_24h')-g(a,'price_change_percentage_24h')).slice(0,12);
const losers=[...rows].sort((a,b)=>g(a,'price_change_percentage_24h')-g(b,'price_change_percentage_24h')).slice(0,12);

let tcoins=[];
for(const item of (tr.coins||[])){
  const it=item.item||{}, d=it.data||{};
  tcoins.push({name:it.name, symbol:(it.symbol||'').toUpperCase(), rank:it.market_cap_rank,
    price:(typeof d.price==='number'?d.price:null),
    pc24:(d.price_change_percentage_24h&&d.price_change_percentage_24h.usd)});
}
const trendSyms=new Set(tcoins.map(t=>t.symbol).filter(Boolean));

function fmt(c,i){
  return `${i}. ${(c.symbol||'').toUpperCase()} (${c.name}) #${c.market_cap_rank} px=${g(c,'current_price')} 24h=${g(c,'price_change_percentage_24h').toFixed(1)} 7d=${g(c,'price_change_percentage_7d_in_currency').toFixed(1)} 1h=${g(c,'price_change_percentage_1h_in_currency').toFixed(1)} vol=${(g(c,'total_volume')/1e6).toFixed(1)}M mcap=${(g(c,'market_cap')/1e6).toFixed(0)}M ${trendSyms.has((c.symbol||'').toUpperCase())?'*TREND*':''}`;
}
console.log('\n=== WINNERS ===');
winners.forEach((c,i)=>console.log(fmt(c,i+1)));
console.log('\n=== LOSERS ===');
losers.forEach((c,i)=>console.log(fmt(c,i+1)));
console.log('\n=== TRENDING ===');
tcoins.slice(0,8).forEach((t,i)=>console.log(`${i+1}. ${t.name} (${t.symbol}) #${t.rank} px=${t.price??'?'} 24h=${t.pc24!=null?t.pc24.toFixed(1):'?'}`));
