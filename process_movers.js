const fs = require('fs');
const m = JSON.parse(fs.readFileSync('markets.json'));
const tr = JSON.parse(fs.readFileSync('trending.json'));

const STABLE = new Set(['tether','usd-coin','dai','first-digital-usd','usde','tusd','usdd','pyusd','fdusd','paxg',
  'ethena-usde','binance-usd','usds','sky-dollar','ripple-usd','blackrock-usd-institutional-digital-liquidity-fund']);
const WRAPPED = new Set(['wrapped-bitcoin','weth','wrapped-eth','staked-ether','wrapped-steth','coinbase-wrapped-btc',
  'wrapped-beacon-eth','lombard-staked-btc','wrapped-eeth','rocket-pool-eth','mantle-staked-ether',
  'bridged-wrapped-steth-axelar','solv-btc','kelp-dao-restaked-eth','renzo-restaked-eth','jupiter-staked-sol',
  'jito-staked-sol','binance-staked-sol','msol','coinbase-wrapped-staked-eth','tbtc','wrapped-avax',
  'binance-bridged-usdt-bnb-smart-chain']);

function isStable(c){
  const sym=(c.symbol||'').toUpperCase(), name=(c.name||'').toLowerCase(), id=c.id||'';
  if(STABLE.has(id)) return true;
  if(name.includes('stablecoin')) return true;
  for(const p of ['USD','EUR','GBP']) if(sym.startsWith(p)) return true;
  return false;
}
const p24=c=>c.price_change_percentage_24h_in_currency!=null?c.price_change_percentage_24h_in_currency:c.price_change_percentage_24h;
const p7=c=>c.price_change_percentage_7d_in_currency;
const p1=c=>c.price_change_percentage_1h_in_currency;

const filt=m.filter(c=>!isStable(c)&&!WRAPPED.has(c.id)&&(c.total_volume||0)>=1e6&&p24(c)!=null);

const srt=[...filt].sort((a,b)=>p24(a)-p24(b));
const losers=srt.slice(0,10);
const winners=srt.slice(-10).reverse();

const trending=(tr.coins||[]).slice(0,7).map(x=>{
  const it=x.item, d=it.data||{};
  return {name:it.name,symbol:(it.symbol||'').toUpperCase(),rank:it.market_cap_rank,
    price:d.price,p24:(d.price_change_percentage_24h||{}).usd,id:it.id};
});
const trendIds=new Set(trending.map(t=>t.id));
const trendSyms=new Set(trending.map(t=>t.symbol));

const top100=filt.slice(0,100);
const green=top100.filter(c=>(p24(c)||0)>0).length;
const top50vals=filt.slice(0,50).map(c=>p24(c)).sort((a,b)=>a-b);
const n=top50vals.length;
const median50=n%2?top50vals[(n-1)/2]:(top50vals[n/2-1]+top50vals[n/2])/2;

function tags(c){
  let t=[]; const v24=p24(c)||0, v7=p7(c), rank=c.market_cap_rank||9999, mcap=c.market_cap||0, vol=c.total_volume||0;
  const intrend=trendIds.has(c.id)||trendSyms.has((c.symbol||'').toUpperCase());
  if(intrend&&v24>0)t.push('TRENDING+UP');
  if(intrend&&v24<0)t.push('TRENDING+DOWN');
  if(v24>15&&(v7||0)>25)t.push('BREAKOUT');
  if(v24>20&&v7!=null&&v7<0)t.push('FADE');
  if(v24<-10&&mcap>0&&vol/mcap>0.25)t.push('CAPITULATION');
  if(rank>150&&v24>30)t.push('PUMP-RISK');
  if(mcap>0&&mcap<50e6)t.push('MICROCAP');
  if(rank<=20)t.push('MAJOR');
  if(t.includes('PUMP-RISK'))t=['PUMP-RISK',...t.filter(x=>x!=='PUMP-RISK')];
  return t.slice(0,2);
}
function fp(p){ if(p==null)return '?'; if(p>=1000)return '$'+p.toLocaleString('en-US',{maximumFractionDigits:0});
  if(p>=1)return '$'+p.toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
  if(p>=0.01)return '$'+p.toFixed(4); return '$'+p.toFixed(6);}
function fb(v){ if(v==null)return '?'; if(v>=1e9)return '$'+(v/1e9).toFixed(1)+'B'; if(v>=1e6)return '$'+(v/1e6).toFixed(0)+'M'; return '$'+(v/1e3).toFixed(0)+'K';}
function line(c,i){
  const v24=p24(c),v7=p7(c),v1=p1(c),tg=tags(c);
  const ts=tg.length?'  ['+tg.join(', ')+']':'';
  const s7='7d '+(v7!=null?(v7>=0?'+':'')+v7.toFixed(0)+'%':'n/a');
  const s1='1h '+(v1!=null?(v1>=0?'+':'')+v1.toFixed(1)+'%':'n/a');
  return `${i}. ${(c.symbol||'').toUpperCase()} (${c.name}) — ${fp(c.current_price)}  ${(v24>=0?'+':'')+v24.toFixed(1)}% / ${s7} / ${s1}  •  ${fb(c.total_volume)} / #${c.market_cap_rank}${ts}`;
}
let out=[];
out.push(`PULSE: green top100 ${green}/100, median top50 ${(median50>=0?'+':'')+median50.toFixed(2)}%`);
out.push('\n=== WINNERS ===');
winners.forEach((c,i)=>out.push(line(c,i+1)));
out.push('\n=== LOSERS ===');
losers.forEach((c,i)=>out.push(line(c,i+1)));
out.push('\n=== TRENDING ===');
const winSyms=new Set(winners.map(w=>(w.symbol||'').toUpperCase()));
const loseSyms=new Set(losers.map(l=>(l.symbol||'').toUpperCase()));
trending.forEach((t,i)=>{
  let tg=[]; if(winSyms.has(t.symbol))tg.push('TRENDING+UP'); if(loseSyms.has(t.symbol))tg.push('TRENDING+DOWN');
  const ps=typeof t.price==='number'?fp(t.price):String(t.price);
  const vs=typeof t.p24==='number'?((t.p24>=0?'+':'')+t.p24.toFixed(1)+'%'):'n/a';
  const ts=tg.length?'  ['+tg.join(', ')+']':'';
  out.push(`${i+1}. ${t.name} (${t.symbol}) — #${t.rank}, ${ps}, 24h ${vs}${ts}`);
});
console.log(out.join('\n'));
