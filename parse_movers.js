const fs = require('fs');
const data = JSON.parse(fs.readFileSync('/home/runner/.claude/projects/-home-runner-work-aeon-aeon/843c940b-08b1-4108-9e7d-5fcefdbf121a/tool-results/btr4vc3gn.txt'));

const stableIds = new Set(['tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg','ethena-usde','usds','ripple-usd','hashnote-usyc','global-dollar','usd1-wlfi','tether-gold','blackrock-usd-institutional-digital-liquidity-fund','ondo-us-dollar-yield','paypal-usd']);
const stableSyms = new Set(['USDT','USDC','DAI','TUSD','FDUSD','USDE','PYUSD','USD1','USDS','USDY','RLUSD','USDG','BUIDL','USYC']);

const filtered = data.filter(c => {
  if (stableIds.has(c.id)) return false;
  const sym = (c.symbol||'').toUpperCase();
  if (sym.startsWith('USD')||sym.startsWith('EUR')||sym.startsWith('GBP')) return false;
  if (stableSyms.has(sym)) return false;
  if ((c.name||'').toLowerCase().includes('stablecoin')) return false;
  if ((c.total_volume||0) < 1000000) return false;
  if (c.price_change_percentage_24h == null) return false;
  return true;
});

const by24h = [...filtered].sort((a,b)=>b.price_change_percentage_24h-a.price_change_percentage_24h);

const sign = n => n >= 0 ? '+' : '';
const pct = n => sign(n)+n.toFixed(1)+'%';
const vol = v => v >= 1e9 ? '$'+(v/1e9).toFixed(2)+'B' : '$'+(v/1e6).toFixed(0)+'M';
const mcap = v => v >= 1e9 ? '$'+(v/1e9).toFixed(2)+'B' : '$'+(v/1e6).toFixed(0)+'M';
const price = p => p >= 1 ? '$'+p.toFixed(2) : p >= 0.001 ? '$'+p.toFixed(4) : '$'+p.toExponential(2);

const fmt = c => {
  const ch7 = c.price_change_percentage_7d_in_currency || 0;
  const ch1 = c.price_change_percentage_1h_in_currency || 0;
  return c.symbol.toUpperCase()+' ('+c.name+') | #'+c.market_cap_rank+' | 24h '+pct(c.price_change_percentage_24h)+' | 7d '+pct(ch7)+' | 1h '+pct(ch1)+' | vol '+vol(c.total_volume)+' | mcap '+mcap(c.market_cap)+' | '+price(c.current_price);
};

console.log('=== TOP 15 WINNERS ===');
by24h.slice(0,15).forEach(c=>console.log(fmt(c)));

console.log('\n=== TOP 15 LOSERS ===');
by24h.slice(-15).reverse().forEach(c=>console.log(fmt(c)));

const top100 = filtered.filter(c=>c.market_cap_rank&&c.market_cap_rank<=100);
const green = top100.filter(c=>c.price_change_percentage_24h>0).length;
const changes = top100.map(c=>c.price_change_percentage_24h).sort((a,b)=>a-b);
const median = changes[Math.floor(changes.length/2)];
console.log('\n=== MARKET PULSE ===');
console.log('Top 100 filtered: '+top100.length+' coins, '+green+' green ('+Math.round(green/top100.length*100)+'%)');
console.log('Median 24h: '+pct(median));
