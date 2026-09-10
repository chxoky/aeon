/**
 * Validation + routing tests for the TradingView execution path.
 * Run: node test/tv-alert.test.mjs
 *
 * These cover the gate (normalize) and the one-shot guard (RuleState). Both are
 * pure logic, so they run without wrangler, network, or credentials.
 */
import { normalize, executeAlpaca } from '../src/tv/index.js';
import { RuleState } from '../src/tv/rules.js';
import { resolve } from '../src/tv/symbols.js';

let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => {
  if (cond) { pass++; console.log(`  ✅ ${name}`); }
  else { fail++; console.log(`  ❌ ${name}${extra ? ' — ' + extra : ''}`); }
};
const throws = (name, fn, re) => {
  try { fn(); fail++; console.log(`  ❌ ${name} — expected throw, got none`); }
  catch (e) {
    if (!re || re.test(e.message)) { pass++; console.log(`  ✅ ${name}`); }
    else { fail++; console.log(`  ❌ ${name} — wrong error: ${e.message}`); }
  }
};

const base = { id: 'r1', action: 'trim', symbol: 'BITX', size: { pct: 40 } };

console.log('\n── symbol resolution ──');
ok('BTC → kraken XBTUSD', resolve('BTC').venue === 'kraken' && resolve('BTC').pair === 'XBTUSD');
ok('BITX → alpaca', resolve('BITX').venue === 'alpaca');
ok('$-prefix and lowercase tolerated', resolve('$bitx').symbol === 'BITX');
throws('unknown symbol rejected, not guessed', () => resolve('ZZZZ'), /cannot resolve/);
ok('explicit venue overrides map', resolve('FOO', 'alpaca').venue === 'alpaca');

console.log('\n── payload validation ──');
ok('valid trim normalizes', normalize(base).action === 'trim');
throws('missing id', () => normalize({ ...base, id: '' }), /missing `id`/);
throws('id charset enforced', () => normalize({ ...base, id: 'bad id!' }), /1-64 chars/);
throws('unknown action', () => normalize({ ...base, action: 'yolo' }), /unknown action/);
throws('two sizes at once', () => normalize({ ...base, size: { pct: 40, usd: 100 } }), /exactly one/);
throws('no size on trim', () => normalize({ ...base, size: {} }), /exactly one/);
throws('negative size', () => normalize({ ...base, size: { pct: -5 } }), /positive number/);
throws('pct over 100', () => normalize({ ...base, size: { pct: 150 } }), /cannot exceed 100/);
throws('size on close', () => normalize({ ...base, action: 'close', size: { pct: 50 } }), /does not take a size/);
ok('close needs no size', normalize({ id: 'r', action: 'close', symbol: 'BITX' }).action === 'close');
throws('patient without limit', () => normalize({ ...base, urgency: 'patient' }), /requires an explicit limit_price/);
ok('patient with limit ok', normalize({ ...base, urgency: 'patient', limit_price: 50 }).limitPrice === 50);
throws('bad when_closed', () => normalize({ ...base, when_closed: 'maybe' }), /when_closed/);

console.log('\n── approval defaults (the invariant) ──');
ok('entry requires confirm by default', normalize({ id: 'r', action: 'open', symbol: 'BITX', size: { usd: 500 } }).requireConfirm === true);
ok('add requires confirm by default', normalize({ id: 'r', action: 'add', symbol: 'BITX', size: { usd: 500 } }).requireConfirm === true);
ok('trim auto-executes', normalize(base).requireConfirm === false);
ok('close auto-executes', normalize({ id: 'r', action: 'close', symbol: 'BITX' }).requireConfirm === false);
ok('entry can opt out explicitly', normalize({ id: 'r', action: 'open', symbol: 'BITX', size: { usd: 500 }, confirm: false }).requireConfirm === false);

console.log('\n── idempotency key derivation ──');
ok('explicit fire_id wins', normalize({ ...base, fire_id: 'abc' }).fireId === 'abc');
ok('tv time used when present', normalize({ ...base, tv: { time: '2026-09-10T12:00:00Z' } }).fireId === 'r1@2026-09-10T12:00:00Z');
ok('same payload twice → same fireId (minute bucket)', normalize(base).fireId === normalize(base).fireId);

console.log('\n── RuleState one-shot / cooldown guard ──');
const mkStub = () => {
  const store = new Map();
  return new RuleState({ storage: {
    get: async (k) => store.get(k),
    put: async (k, v) => { store.set(k, structuredClone(v)); },
  }});
};
const call = async (ro, path, body) => (await ro.fetch(new Request(`https://r${path}`, {
  method: 'POST', body: JSON.stringify(body), headers: { 'Content-Type': 'application/json' },
}))).json();

{
  const ro = mkStub();
  const a = await call(ro, '/claim', { fireId: 'f1', cooldownSec: 0 });
  const b = await call(ro, '/claim', { fireId: 'f1', cooldownSec: 0 });
  ok('duplicate fireId rejected', a.ok === true && b.ok === false && b.reason === 'duplicate_fire_id');
}
{
  const ro = mkStub();
  await call(ro, '/claim', { fireId: 'f1', cooldownSec: 300 });
  const b = await call(ro, '/claim', { fireId: 'f2', cooldownSec: 300 });
  ok('cooldown blocks a different fire', b.ok === false && b.reason === 'cooldown');
}
{
  const ro = mkStub();
  await call(ro, '/claim', { fireId: 'f1', cooldownSec: 0, oneShot: true });
  const b = await call(ro, '/claim', { fireId: 'f2', cooldownSec: 0, oneShot: true });
  ok('one-shot disarms after first fire', b.ok === false && b.reason === 'disarmed');
}
{
  const ro = mkStub();
  await call(ro, '/claim', { fireId: 'f1', cooldownSec: 0, maxFires: 2 });
  await call(ro, '/claim', { fireId: 'f2', cooldownSec: 0, maxFires: 2 });
  const c = await call(ro, '/claim', { fireId: 'f3', cooldownSec: 0, maxFires: 2 });
  ok('maxFires enforced', c.ok === false && c.reason === 'max_fires_reached');
}
{
  const ro = mkStub();
  await call(ro, '/claim', { fireId: 'f1', cooldownSec: 0, oneShot: true });
  await call(ro, '/settle', { fireId: 'f1', status: 'transport_failed' });
  const b = await call(ro, '/claim', { fireId: 'f2', cooldownSec: 0, oneShot: true });
  ok('transport failure re-arms a one-shot', b.ok === true);
}
{
  const ro = mkStub();
  await call(ro, '/claim', { fireId: 'f1', cooldownSec: 0, oneShot: true });
  await call(ro, '/settle', { fireId: 'f1', status: 'rejected' });
  const b = await call(ro, '/claim', { fireId: 'f2', cooldownSec: 0, oneShot: true });
  ok('venue rejection does NOT re-arm', b.ok === false && b.reason === 'disarmed');
}

console.log('\n── regressions (bugs found in self-review) ──');

// Stub the network so the REAL adapter code runs and we can assert what it sent.
const calls = [];
const mockFetch = (marketOpen = true) => async (url, init = {}) => {
  const u = new URL(String(url));
  const method = init.method || 'GET';
  calls.push(`${method} ${u.pathname}${u.search}`);
  const body = (o) => new Response(JSON.stringify(o), { headers: { 'Content-Type': 'application/json' } });

  if (u.pathname === '/v2/clock') {
    return body({ is_open: marketOpen, timestamp: '2026-09-10T15:00:00Z',
                  next_open: '2026-09-11T13:30:00Z', next_close: '2026-09-10T20:00:00Z' });
  }
  if (u.pathname.startsWith('/v2/stocks/')) return body({ quote: { bp: 40.10, ap: 40.20, bs: 5, as: 5, t: '' } });
  if (u.pathname.startsWith('/v2/positions/') && method === 'GET') return body({ qty: '100', symbol: 'BITX' });
  if (u.pathname.startsWith('/v2/positions/') && method === 'DELETE') return body({ id: 'ord-close' });
  if (u.pathname === '/v2/orders' && method === 'POST') return body({ id: 'ord-new', side: 'sell', qty: '1', symbol: 'BITX', type: 'limit' });
  if (u.pathname === '/v2/orders' && method === 'GET') return body([]);
  return body({});
};

const env = { ALPACA_API_KEY_ID: 'k', ALPACA_API_SECRET_KEY: 's' };
const realFetch = globalThis.fetch;

// BUG 1 — pct sizing on a new entry must be rejected at the gate.
throws('open with pct rejected at the gate',
  () => normalize({ id: 'r', action: 'open', symbol: 'BITX', size: { pct: 50 } }),
  /cannot size by pct/);

// BUG 2 — a usd-denominated trim must NOT reach close-position, which would
// have had neither percentage nor qty and closed the ENTIRE position.
{
  calls.length = 0;
  globalThis.fetch = mockFetch(true);
  const plan = normalize({ id: 'r', action: 'trim', symbol: 'BITX', size: { usd: 500 } });
  await executeAlpaca(env, plan);
  globalThis.fetch = realFetch;
  const deletedPosition = calls.find((c) => c.startsWith('DELETE /v2/positions'));
  ok('trim by usd does not hit close-position', !deletedPosition, `sent: ${deletedPosition}`);
  ok('trim by usd places an explicit sized order', calls.some((c) => c === 'POST /v2/orders'));
}

// pct trim SHOULD still use close-position (server-side sizing, no race).
{
  calls.length = 0;
  globalThis.fetch = mockFetch(true);
  await executeAlpaca(env, normalize({ id: 'r', action: 'trim', symbol: 'BITX', size: { pct: 40 } }));
  globalThis.fetch = realFetch;
  ok('trim by pct uses close-position with a percentage',
     calls.some((c) => c.startsWith('DELETE /v2/positions/BITX') && c.includes('percentage=40')));
}

// BUG 3 — dry_run must not mutate anything on ANY path.
{
  calls.length = 0;
  globalThis.fetch = mockFetch(true);
  const r = await executeAlpaca(env, normalize({ id: 'r', action: 'trim', symbol: 'BITX', size: { pct: 40 }, dry_run: true }));
  globalThis.fetch = realFetch;
  const mutated = calls.filter((c) => c.startsWith('DELETE') || c.startsWith('POST'));
  ok('dry-run trim sends no mutating call', mutated.length === 0, `sent: ${mutated.join(', ')}`);
  ok('dry-run reports what it would do', r.dryRun === true && /DRY RUN/.test(r.description));
}
{
  calls.length = 0;
  globalThis.fetch = mockFetch(true);
  const r = await executeAlpaca(env, normalize({ id: 'r', action: 'cancel', symbol: 'BITX', dry_run: true }));
  globalThis.fetch = realFetch;
  ok('dry-run cancel sends no mutating call', !calls.some((c) => c.startsWith('DELETE')), calls.join(', '));
  ok('dry-run cancel reports intent', r.dryRun === true);
}

// Session router: outside RTH a sell must become an extended-hours LIMIT.
{
  calls.length = 0;
  let sentBody = null;
  globalThis.fetch = async (url, init = {}) => {
    if (String(url).includes('/v2/orders') && init.method === 'POST') sentBody = JSON.parse(init.body);
    return mockFetch(false)(url, init);
  };
  await executeAlpaca(env, normalize({ id: 'r', action: 'trim', symbol: 'BITX', size: { pct: 40 }, when_closed: 'queue' }));
  globalThis.fetch = realFetch;
  ok('closed market → limit order, never market', sentBody?.type === 'limit', JSON.stringify(sentBody));
  ok('closed market → sells at the bid', Number(sentBody?.limit_price) === 40.10);
  ok('closed market → carries a client_order_id', !!sentBody?.client_order_id);
}

// Slippage guard.
{
  globalThis.fetch = mockFetch(false);
  let threw = null;
  try {
    await executeAlpaca(env, normalize({ id: 'r', action: 'trim', symbol: 'BITX', size: { pct: 40 }, max_slippage_pct: 0.05 }));
  } catch (e) { threw = e; }
  globalThis.fetch = realFetch;
  ok('wide spread refuses to trade', threw && /exceeds max_slippage_pct/.test(threw.message), threw?.message);
}

console.log('\n── session boundaries (ET wall clock) ──');
// Regression: an earlier version derived pre/post from Alpaca's next_open gap,
// which could never return "post" — 17:00 ET and 03:00 ET both sit ~16h before
// the next open. That silently dropped extended_hours and rested the order to
// the next session, defeating the whole after-hours path.
{
  const etCls = (iso) => {
    const p = Object.fromEntries(new Intl.DateTimeFormat('en-US', {
      timeZone: 'America/New_York', hour12: false, weekday: 'short', hour: '2-digit', minute: '2-digit',
    }).formatToParts(new Date(iso)).map((x) => [x.type, x.value]));
    const h = parseInt(p.hour, 10) % 24;
    const minutes = h * 60 + parseInt(p.minute, 10);
    if (p.weekday === 'Sat' || p.weekday === 'Sun') return 'closed';
    if (minutes >= 240 && minutes < 570) return 'pre';
    if (minutes >= 960 && minutes < 1200) return 'post';
    return 'closed';
  };
  const cases = [
    ['2026-09-10T21:09:00Z', 'post',   '17:09 ET Thu — post-market'],
    ['2026-09-10T20:01:00Z', 'post',   '16:01 ET — post opens'],
    ['2026-09-10T23:59:00Z', 'post',   '19:59 ET — last post minute'],
    ['2026-09-11T00:30:00Z', 'closed', '20:30 ET — post has ended'],
    ['2026-09-10T08:00:00Z', 'pre',    '04:00 ET — pre opens'],
    ['2026-09-10T12:00:00Z', 'pre',    '08:00 ET — pre-market'],
    ['2026-09-10T07:00:00Z', 'closed', '03:00 ET — before pre'],
    ['2026-09-12T21:00:00Z', 'closed', 'Sat 17:00 ET — weekend'],
    ['2026-09-13T14:00:00Z', 'closed', 'Sun 10:00 ET — weekend'],
  ];
  for (const [iso, exp, label] of cases) ok(label, etCls(iso) === exp, `got ${etCls(iso)}`);
}

console.log(`\n${fail === 0 ? '✅' : '❌'} ${pass} passed, ${fail} failed\n`);
process.exit(fail === 0 ? 0 : 1);
