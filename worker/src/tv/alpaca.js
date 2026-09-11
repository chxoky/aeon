/**
 * Alpaca venue adapter — US equities and ETFs.
 *
 * Alpaca is the broker-dealer behind Kraken's own equities product, but unlike
 * Kraken's equities offering it exposes a real trading API *and* supports
 * extended-hours execution — which is why the equity leg routes here.
 *
 * Credential boundary: same rule as kraken.js. APCA keys never enter a model
 * prompt, a Telegram message, or a log line.
 */

const DATA_API = 'https://data.alpaca.markets';

function baseUrl(env) {
  // Default to PAPER. Live trading requires ALPACA_LIVE === 'true' to be set
  // explicitly — an unset or malformed env var must never silently trade real money.
  return env.ALPACA_LIVE === 'true'
    ? 'https://api.alpaca.markets'
    : 'https://paper-api.alpaca.markets';
}

export function isLive(env) {
  return env.ALPACA_LIVE === 'true';
}

function headers(env) {
  const id = env.ALPACA_API_KEY_ID;
  const secret = env.ALPACA_API_SECRET_KEY;
  if (!id || !secret) throw new Error('ALPACA_API_KEY_ID / ALPACA_API_SECRET_KEY not configured');
  return {
    'APCA-API-KEY-ID': id,
    'APCA-API-SECRET-KEY': secret,
    'Content-Type': 'application/json',
  };
}

async function call(env, method, path, { body, query, base } = {}) {
  const url = new URL((base || baseUrl(env)) + path);
  if (query) for (const [k, v] of Object.entries(query)) {
    if (v !== undefined && v !== null) url.searchParams.set(k, String(v));
  }

  const resp = await fetch(url, {
    method,
    headers: headers(env),
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await resp.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON error body */ }

  if (!resp.ok) {
    const msg = json?.message || text || `HTTP ${resp.status}`;
    throw new Error(`Alpaca ${method} ${path}: ${msg}`);
  }
  return json;
}

/**
 * US equity session boundaries, in minutes past ET midnight.
 * Pre 04:00-09:30 · Regular 09:30-16:00 · Post 16:00-20:00
 */
const PRE_OPEN = 4 * 60, RTH_OPEN = 9 * 60 + 30, RTH_CLOSE = 16 * 60, POST_CLOSE = 20 * 60;

/** Wall-clock weekday + minutes-past-midnight in America/New_York. */
function etParts(date) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: 'America/New_York', hour12: false,
      weekday: 'short', hour: '2-digit', minute: '2-digit',
    }).formatToParts(date).map((p) => [p.type, p.value]),
  );
  // hour12:false renders midnight as "24" in some engines.
  const hour = parseInt(parts.hour, 10) % 24;
  return { weekday: parts.weekday, minutes: hour * 60 + parseInt(parts.minute, 10) };
}

/**
 * Market session state, mirroring MarketStatus from charting_library.d.ts:405.
 *
 * Derived from the ET wall clock rather than Alpaca's next_open/next_close.
 * Alpaca's clock only reports is_open, and the boundary arithmetic cannot
 * distinguish post-market from overnight: at 17:00 ET the next open is ~16h away,
 * which reads identically to 3am. An earlier version of this function got that
 * wrong and classified every post-market moment as "closed", which silently
 * dropped extended_hours on the order and rested it until the next session —
 * exactly the case this whole path exists to handle.
 *
 * Known edge: on a full-day market holiday the ET clock still looks like a normal
 * day, so an afternoon holiday reads as "post". The resulting order is a limit
 * order that Alpaca either rejects or leaves unfilled — a visible, reported
 * outcome rather than a silent mis-execution.
 */
export async function marketStatus(env) {
  const clock = await call(env, 'GET', '/v2/clock');
  if (clock.is_open) return { status: 'open', clock };

  const { weekday, minutes } = etParts(new Date(clock.timestamp));
  if (weekday === 'Sat' || weekday === 'Sun') return { status: 'closed', clock };

  if (minutes >= PRE_OPEN && minutes < RTH_OPEN)    return { status: 'pre', clock };
  if (minutes >= RTH_CLOSE && minutes < POST_CLOSE) return { status: 'post', clock };
  return { status: 'closed', clock };
}

/** Latest NBBO quote — the source for "limit at best bid". */
export async function quote(env, symbol) {
  const json = await call(env, 'GET', `/v2/stocks/${encodeURIComponent(symbol)}/quotes/latest`, {
    base: DATA_API,
  });
  const q = json?.quote;
  if (!q) throw new Error(`Alpaca: no quote for ${symbol}`);
  return { bid: q.bp, ask: q.ap, bidSize: q.bs, askSize: q.as, at: q.t };
}

/** Open position for one symbol, or null. */
export async function position(env, symbol) {
  try {
    return await call(env, 'GET', `/v2/positions/${encodeURIComponent(symbol)}`);
  } catch (e) {
    if (/position does not exist|404/i.test(e.message)) return null;
    throw e;
  }
}

/**
 * Place an order.
 *
 * extendedHours is only honoured by Alpaca for type=limit with time_in_force
 * day or gtc — the caller (session router) is responsible for having already
 * downgraded a market order to a limit before setting it. We re-assert it here
 * rather than trusting the caller, because silently sending a market order with
 * extended_hours=true gets it rejected or queued to the open, which is exactly
 * the failure the router exists to prevent.
 */
export async function placeOrder(env, o) {
  if (o.extendedHours && o.type !== 'limit') {
    throw new Error('Alpaca: extended-hours orders must be type=limit');
  }
  const body = {
    symbol: o.symbol,
    side: o.side,
    type: o.type,
    time_in_force: o.timeInForce || 'day',
  };
  if (o.qty != null) body.qty = String(o.qty);
  else if (o.notional != null) body.notional = String(o.notional);
  else throw new Error('Alpaca: order needs qty or notional');

  if (o.type === 'limit') {
    if (o.limitPrice == null) throw new Error('Alpaca limit order requires limit_price');
    body.limit_price = String(o.limitPrice);
  }
  if (o.extendedHours) body.extended_hours = true;
  // client_order_id is a REAL idempotency key: Alpaca rejects a duplicate.
  // This is the second line of defence behind the RuleState DO.
  if (o.clientOrderId) body.client_order_id = o.clientOrderId;

  const order = await call(env, 'POST', '/v2/orders', { body });
  return {
    venue: 'alpaca',
    live: isLive(env),
    orderIds: [order.id],
    clientOrderId: order.client_order_id,
    description: `${order.side} ${order.qty ?? order.notional} ${order.symbol} ${order.type}`,
  };
}

/**
 * Close all or part of a position. Alpaca's DELETE /v2/positions/{symbol}
 * takes qty OR percentage and handles the sizing server-side, which avoids a
 * read-then-write race against a position that is changing underneath us.
 */
export async function closePosition(env, { symbol, percentage, qty }) {
  const query = {};
  if (percentage != null) query.percentage = String(percentage);
  else if (qty != null) query.qty = String(qty);

  const order = await call(env, 'DELETE', `/v2/positions/${encodeURIComponent(symbol)}`, { query });
  return {
    venue: 'alpaca',
    live: isLive(env),
    orderIds: [order.id],
    description: `close ${percentage != null ? percentage + '%' : qty} ${symbol}`,
  };
}

/** Cancel open orders for a symbol. */
export async function cancelOpenOrders(env, symbol) {
  const orders = await call(env, 'GET', '/v2/orders', { query: { status: 'open', symbols: symbol } });
  const cancelled = [];
  for (const o of orders || []) {
    await call(env, 'DELETE', `/v2/orders/${o.id}`);
    cancelled.push(o.id);
  }
  return { venue: 'alpaca', cancelled };
}
