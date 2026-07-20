const fs = require('fs');
const coins = JSON.parse(fs.readFileSync('.movers-cache/markets.json'));
const trending = JSON.parse(fs.readFileSync('.movers-cache/trending.json'));

console.log("total coins:", coins.length);

const STABLE = new Set(['tether','usd-coin','dai','first-digital-usd','usde','ethena-usde','tusd','usdd','pyusd','fdusd','paxg','binance-usd','usds','ripple-usd','usdt0','ondo-us-dollar-yield','ethena-staked-usde']);
function isStable(c){
  const id=(c.id||'').toLowerCase(), sym=(c.symbol||'').toUpperCase(), name=(c.name||'').toLowerCase();
  if(STABLE.has(id))return true;
  if(sym.startsWith('USD')||sym.startsWith('EUR')||sym.startsWith('GBP'))return true;
  if(name.includes('stablecoin'))return true;
  return false;
}
const filtered = coins.filter(c=>{
  if(isStable(c))return false;
  if((c.total_volume||0)<1e6)return false;
  if(c.price_change_percentage_24h_in_currency==null)return false;
  return true;
});
console.log("after filter:", filtered.length);

const byd=c=>c.price_change_percentage_24h_in_currency||0;
const winners=[...filtered].sort((a,b)=>byd(b)-byd(a)).slice(0,10);
const losers=[...filtered].sort((a,b)=>byd(a)-byd(b)).slice(0,10);

function row(c){
  const d7=c.price_change_percentage_7d_in_currency||0, h1=c.price_change_percentage_1h_in_currency||0;
  const mcap=c.market_cap||0, vol=c.total_volume||0;
  console.log(`${(c.symbol||'').toUpperCase().padEnd(7)} ${(c.name||'').slice(0,22).padEnd(22)} #${String(c.market_cap_rank).padEnd(4)} $${c.current_price} | 24h ${byd(c).toFixed(1).padStart(6)} 7d ${d7.toFixed(1).padStart(6)} 1h ${h1.toFixed(1).padStart(5)} | vol ${(vol/1e6).toFixed(1)}M mcap ${(mcap/1e6).toFixed(0)}M volmcap ${(mcap?vol/mcap:0).toFixed(2)}`);
}
console.log("\n=== WINNERS ===");winners.forEach(row);
console.log("\n=== LOSERS ===");losers.forEach(row);

const top100=filtered.slice(0,100);
const green=top100.filter(c=>byd(c)>0).length;
const median=a=>{const s=[...a].sort((x,y)=>x-y);const m=Math.floor(s.length/2);return s.length%2?s[m]:(s[m-1]+s[m])/2;};
console.log("\n=== PULSE ===");
console.log(`top100 green: ${green}/${top100.length}  median50: ${median(filtered.slice(0,50).map(byd)).toFixed(2)}%  median100: ${median(top100.map(byd)).toFixed(2)}%`);

console.log("\n=== MAJORS ===");
filtered.slice(0,12).forEach(c=>console.log(`  ${(c.symbol||'').toUpperCase().padEnd(6)} 24h ${byd(c).toFixed(1).padStart(6)}% 7d ${(c.price_change_percentage_7d_in_currency||0).toFixed(1).padStart(6)}%`));

const trendSyms=new Set();
console.log("\n=== TRENDING ===");
(trending.coins||[]).slice(0,10).forEach(it=>{
  const ci=it.item, data=ci.data||{};
  let ch=null; if(data.price_change_percentage_24h) ch=data.price_change_percentage_24h.usd;
  trendSyms.add((ci.symbol||'').toUpperCase());
  console.log(`  ${(ci.symbol||'').toUpperCase().padEnd(8)} ${(ci.name||'').slice(0,22).padEnd(22)} rank #${ci.market_cap_rank}  price $${data.price}  24h ${ch!=null?ch.toFixed(1):'n/a'}`);
});
const winSyms=new Set(winners.map(c=>(c.symbol||'').toUpperCase()));
const loseSyms=new Set(losers.map(c=>(c.symbol||'').toUpperCase()));
console.log("\nTrend∩Winners:", [...trendSyms].filter(s=>winSyms.has(s)));
console.log("Trend∩Losers:", [...trendSyms].filter(s=>loseSyms.has(s)));
