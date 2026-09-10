/**
 * Kraken venue adapter — crypto spot.
 *
 * Credential boundary: this module is deterministic code and is the ONLY place
 * KRAKEN_API_KEY / KRAKEN_API_SECRET are touched in the Worker. They must never
 * be placed into an Anthropic API request, a Telegram message, or a log line.
 * This mirrors the postprocess-kraken.sh invariant (the model never sees keys) —
 * here the "not-a-model" boundary is the module, not the process.
 *
 * NONCE COMPATIBILITY: scripts/postprocess-kraken.sh uses millisecond nonces
 * (int(time.time()*1000)). Kraken requires a strictly increasing nonce per API
 * key, so this module MUST stay on milliseconds too — switching to microseconds
 * here would make every subsequent shell-script order fail with "Invalid nonce".
 */

const API = 'https://api.kraken.com';

// Monotonic guard: two orders in the same millisecond inside one isolate would
// otherwise reuse a nonce. Cross-isolate collisions remain possible; widen the
// key's nonce window in Kraken's API settings if you ever see EAPI:Invalid nonce.
let lastNonce = 0;
function nextNonce() {
  const n = Math.max(Date.now(), lastNonce + 1);
  lastNonce = n;
  return String(n);
}

const enc = new TextEncoder();

function b64encode(buf) {
  const bytes = new Uint8Array(buf);
  let s = '';
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s);
}

function b64decode(str) {
  const bin = atob(str);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/**
 * Kraken's documented signing scheme:
 *   HMAC-SHA512( urlpath + SHA256(nonce + postdata), base64decode(secret) )
 * base64-encoded. Byte-for-byte identical to postprocess-kraken.sh.
 */
async function sign(urlpath, nonce, postdata, secret) {
  const sha256 = await crypto.subtle.digest('SHA-256', enc.encode(nonce + postdata));
  const message = new Uint8Array(urlpath.length + sha256.byteLength);
  message.set(enc.encode(urlpath), 0);
  message.set(new Uint8Array(sha256), urlpath.length);

  const key = await crypto.subtle.importKey(
    'raw', b64decode(secret),
    { name: 'HMAC', hash: 'SHA-512' },
    false, ['sign'],
  );
  return b64encode(await crypto.subtle.sign('HMAC', key, message));
}

async function privateCall(env, path, params = {}) {
  const key = env.KRAKEN_API_KEY;
  const secret = env.KRAKEN_API_SECRET;
  if (!key || !secret) throw new Error('KRAKEN_API_KEY / KRAKEN_API_SECRET not configured');

  const nonce = nextNonce();
  const body = new URLSearchParams({ nonce, ...params });
  const postdata = body.toString();
  const urlpath = `/0/private/${path}`;

  const resp = await fetch(API + urlpath, {
    method: 'POST',
    headers: {
      'API-Key': key,
      'API-Sign': await sign(urlpath, nonce, postdata, secret),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: postdata,
  });

  const json = await resp.json();
  if (json.error && json.error.length) {
    throw new Error(`Kraken ${path}: ${json.error.join('; ')}`);
  }
  return json.result;
}

async function publicCall(path, query = {}) {
  const qs = new URLSearchParams(query).toString();
  const resp = await fetch(`${API}/0/public/${path}${qs ? '?' + qs : ''}`);
  const json = await resp.json();
  if (json.error && json.error.length) {
    throw new Error(`Kraken ${path}: ${json.error.join('; ')}`);
  }
  return json.result;
}

/** Best bid / ask / last for a pair. */
export async function quote(pair) {
  const result = await publicCall('Ticker', { pair });
  const row = Object.values(result)[0];
  if (!row) throw new Error(`Kraken: no ticker for ${pair}`);
  return {
    bid:  parseFloat(row.b[0]),
    ask:  parseFloat(row.a[0]),
    last: parseFloat(row.c[0]),
  };
}

/**
 * Spot balance for one asset. Kraken spot has balances, not positions — a
 * "trim 40%" on crypto means 40% of the free balance of the base asset.
 */
export async function assetBalance(env, asset) {
  const balances = await privateCall(env, 'Balance');
  // Kraken returns legacy-prefixed asset codes (XXBT, XETH, ZUSD) alongside
  // modern ones. Match the plain code, then the X/Z-prefixed variants.
  const candidates = [asset, `X${asset}`, `Z${asset}`, asset.replace(/^XBT$/, 'XXBT')];
  for (const c of candidates) {
    if (balances[c] !== undefined) return parseFloat(balances[c]);
  }
  return 0;
}

/**
 * Place an order.
 *
 * @param {object} o
 * @param {string} o.pair       Kraken pair, e.g. XBTUSD
 * @param {'buy'|'sell'} o.side
 * @param {'market'|'limit'} o.ordertype
 * @param {number} o.volume     base-asset units
 * @param {number} [o.price]    required for limit
 * @param {number} [o.userref]  32-bit signed int; Kraken's client reference.
 *                              Used here as a weak idempotency marker — Kraken
 *                              does NOT reject duplicate userrefs, so the real
 *                              one-shot guarantee lives in the RuleState DO.
 * @param {boolean} [o.dryRun]  send validate=true — Kraken checks the order and
 *                              returns the parsed description WITHOUT placing it.
 */
export async function placeOrder(env, o) {
  const params = {
    pair: o.pair,
    type: o.side,
    ordertype: o.ordertype,
    volume: String(o.volume),
  };
  if (o.ordertype === 'limit') {
    if (o.price == null) throw new Error('Kraken limit order requires a price');
    params.price = String(o.price);
  }
  if (o.userref != null) params.userref = String(o.userref);
  if (o.dryRun) params.validate = 'true';

  const result = await privateCall(env, 'AddOrder', params);
  return {
    venue: 'kraken',
    dryRun: !!o.dryRun,
    orderIds: result.txid || [],
    description: result.descr?.order || null,
  };
}

/** Cancel every open order for a pair. Used by the `cancel` action. */
export async function cancelOpenOrders(env, pair) {
  const open = await privateCall(env, 'OpenOrders');
  const ids = Object.entries(open.open || {})
    .filter(([, ord]) => !pair || ord.descr?.pair === pair)
    .map(([id]) => id);

  const cancelled = [];
  for (const id of ids) {
    await privateCall(env, 'CancelOrder', { txid: id });
    cancelled.push(id);
  }
  return { venue: 'kraken', cancelled };
}
