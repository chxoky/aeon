/**
 * TradingView alert → order execution.
 *
 * TradingView never touches a brokerage. An alert fires a webhook into this
 * handler; this handler decides, sizes, routes and executes. TradingView is the
 * eyes; this file is the hands.
 *
 * PIPELINE
 *   verify secret → parse+validate → resolve venue → CLAIM (Durable Object)
 *     → approval gate (new entries) → session router → size → execute → settle → notify
 *
 * APPROVAL MODEL — deliberately mirrors the invariant already documented in
 * skills/kraken-execute/SKILL.md and skills/close-trade/SKILL.md:
 *   • exits (trim / close / cancel) on an existing position — auto-execute.
 *     close-trade already calls this the "mirror-initiated, no approval needed" path.
 *   • entries (open / add) — require confirmation by DEFAULT.
 * Setting "confirm": false on an entry rule moves the approval upstream: you are
 * approving the entry when you arm the rule rather than when it fires. That is a
 * real change to the boundary you set, so it is opt-in per rule and never implicit.
 */

import * as kraken from './kraken.js';
import * as alpaca from './alpaca.js';
import { resolve as resolveSymbol } from './symbols.js';
import { ruleCall } from './rules.js';

const EXIT_ACTIONS  = new Set(['trim', 'close', 'cancel']);
const ENTRY_ACTIONS = new Set(['open', 'add']);
const ALL_ACTIONS   = new Set([...EXIT_ACTIONS, ...ENTRY_ACTIONS]);

// ── Entry point ───────────────────────────────────────────────────────────────

export async function handleTvAlert(request, env, ctx) {
  let payload;
  try {
    payload = await parseBody(request);
  } catch (e) {
    return text(400, `bad payload: ${e.message}`);
  }

  // Auth. TradingView cannot set custom request headers on webhook alerts, so
  // the shared secret travels in the body. Constant-time compare.
  if (!env.TV_WEBHOOK_SECRET) return text(500, 'TV_WEBHOOK_SECRET not configured');
  if (!safeEqual(String(payload.secret || ''), env.TV_WEBHOOK_SECRET)) {
    return text(401, 'unauthorized');
  }

  let plan;
  try {
    plan = normalize(payload);
  } catch (e) {
    ctx.waitUntil(notify(env, `⚠️ *TV alert rejected*\n\n${escapeMd(e.message)}\n\nPayload id: \`${escapeMd(String(payload.id || 'none'))}\``));
    return text(400, `invalid alert: ${e.message}`);
  }

  // Claim the fire slot BEFORE doing anything with side effects.
  const claim = await ruleCall(env, plan.ruleId, '/claim', {
    fireId: plan.fireId,
    cooldownSec: plan.cooldownSec,
    maxFires: plan.maxFires,
    oneShot: plan.oneShot,
    meta: { action: plan.action, symbol: plan.symbol },
  });

  if (!claim.ok) {
    // Not an error — this is the guard doing its job. 200 so TradingView does
    // not retry into a hot loop.
    return text(200, `skipped: ${claim.reason}`);
  }

  // Entry actions pause here for confirmation unless the rule opted out.
  if (ENTRY_ACTIONS.has(plan.action) && plan.requireConfirm) {
    await env.BOT_STATE.put(`tv_pending:${plan.ruleId}`, JSON.stringify(plan), { expirationTtl: 3600 });
    ctx.waitUntil(notify(env, pendingMessage(plan)));
    await ruleCall(env, plan.ruleId, '/settle', { fireId: plan.fireId, status: 'awaiting_confirm' });
    return text(200, 'awaiting confirmation');
  }

  ctx.waitUntil(executeAndReport(env, plan));
  return text(200, 'accepted');
}

/**
 * Rule inspection and re-arming: POST /tv-rule {secret, id, op}
 *   op "status" (default) — read fire count, armed flag, and recent history
 *   op "rearm"            — restore the fire slot on a spent one-shot rule
 *                           (add {"reset_fires": true} to zero the lifetime count)
 *
 * Read-only by default and behind the same shared secret as the alert endpoint.
 * This is the operational surface for "did that actually fire, and what happened".
 */
export async function handleTvRule(request, env) {
  let body;
  try { body = await request.json(); } catch { return text(400, 'body must be JSON'); }

  if (!env.TV_WEBHOOK_SECRET) return text(500, 'TV_WEBHOOK_SECRET not configured');
  if (!safeEqual(String(body.secret || ''), env.TV_WEBHOOK_SECRET)) return text(401, 'unauthorized');

  const id = String(body.id || '').trim();
  if (!id) return text(400, 'missing `id`');

  const op = String(body.op || 'status').toLowerCase();
  if (op === 'rearm') {
    const r = await ruleCall(env, id, '/rearm', { resetFires: !!body.reset_fires });
    return json({ id, op, ...r });
  }
  if (op !== 'status') return text(400, 'op must be "status" or "rearm"');

  const r = await ruleCall(env, id, '/state', {});
  return json({ id, op, rule: r });
}

/** Called from the Telegram handler when Kyle replies `go <ruleId>` / `deny <ruleId>`. */
export async function resolvePending(env, ctx, ruleId, approved) {
  const raw = await env.BOT_STATE.get(`tv_pending:${ruleId}`);
  // null (not a message) so the Telegram handler can fall through to freeform —
  // otherwise an ordinary "go check the charts" gets swallowed by this branch.
  if (!raw) return null;

  await env.BOT_STATE.delete(`tv_pending:${ruleId}`);
  const plan = JSON.parse(raw);

  if (!approved) {
    await ruleCall(env, ruleId, '/settle', { fireId: plan.fireId, status: 'denied' });
    return `❌ Denied — ${plan.action} ${plan.symbol} not executed.`;
  }

  ctx.waitUntil(executeAndReport(env, plan));
  return `⏳ Executing ${plan.action} ${plan.symbol} on ${plan.venue}...`;
}

// ── Payload handling ──────────────────────────────────────────────────────────

async function parseBody(request) {
  const raw = await request.text();
  if (!raw.trim()) throw new Error('empty body');
  try {
    return JSON.parse(raw);
  } catch {
    throw new Error('body must be JSON (paste the JSON into the alert message field)');
  }
}

/**
 * Validate and normalize an alert into an execution plan.
 * Everything downstream trusts this shape, so every check lives here.
 */
export function normalize(p) {
  const ruleId = String(p.id || '').trim();
  if (!ruleId) throw new Error('missing `id` (a stable rule identifier)');
  if (!/^[\w.:-]{1,64}$/.test(ruleId)) throw new Error('`id` must be 1-64 chars of [A-Za-z0-9_.:-]');

  const action = String(p.action || '').trim().toLowerCase();
  if (!ALL_ACTIONS.has(action)) {
    throw new Error(`unknown action "${action}" — expected one of ${[...ALL_ACTIONS].join(', ')}`);
  }

  const resolved = resolveSymbol(p.symbol, p.venue, p.pair);

  // Size. Exactly one of pct / usd / qty, except for close and cancel.
  const size = p.size || {};
  const given = ['pct', 'usd', 'qty'].filter((k) => size[k] != null);
  if (action === 'close' || action === 'cancel') {
    if (given.length) throw new Error(`action "${action}" does not take a size`);
  } else if (given.length !== 1) {
    throw new Error(`size must specify exactly one of pct / usd / qty (got ${given.length})`);
  } else if (ENTRY_ACTIONS.has(action) && size.pct != null) {
    // "40% of position" is meaningless when opening one. Fail at the gate rather
    // than deep inside the venue adapter.
    throw new Error(`action "${action}" cannot size by pct — use usd or qty`);
  }
  for (const k of given) {
    const v = Number(size[k]);
    if (!Number.isFinite(v) || v <= 0) throw new Error(`size.${k} must be a positive number`);
    if (k === 'pct' && v > 100) throw new Error('size.pct cannot exceed 100');
    size[k] = v;
  }

  const urgency = String(p.urgency || 'fast').toLowerCase();
  if (!['fast', 'patient'].includes(urgency)) throw new Error('urgency must be "fast" or "patient"');
  if (urgency === 'patient' && p.limit_price == null) {
    throw new Error('urgency "patient" requires an explicit limit_price');
  }

  const whenClosed = String(p.when_closed || 'queue').toLowerCase();
  if (!['queue', 'abort'].includes(whenClosed)) throw new Error('when_closed must be "queue" or "abort"');

  // Entry actions default to requiring confirmation; exits default to auto.
  const requireConfirm = p.confirm != null ? !!p.confirm : ENTRY_ACTIONS.has(action);

  // Idempotency. Prefer an explicit fire_id, then TradingView's alert timestamp,
  // then a per-minute bucket so a duplicate delivery of the same alert collapses.
  const tvTime = p.tv?.time || p.time || null;
  const fireId = String(
    p.fire_id || (tvTime ? `${ruleId}@${tvTime}` : `${ruleId}@${Math.floor(Date.now() / 60000)}`),
  );

  return {
    ruleId, action, urgency, whenClosed, requireConfirm, fireId,
    venue: resolved.venue,
    symbol: resolved.symbol,
    pair: resolved.pair || null,
    asset: resolved.asset || null,
    size,
    limitPrice: p.limit_price != null ? Number(p.limit_price) : null,
    maxSlippagePct: p.max_slippage_pct != null ? Number(p.max_slippage_pct) : null,
    cooldownSec: p.cooldown_sec != null ? Number(p.cooldown_sec) : 60,
    maxFires: p.max_fires != null ? Number(p.max_fires) : null,
    oneShot: p.one_shot != null ? !!p.one_shot : false,
    dryRun: !!p.dry_run,
    note: p.note ? String(p.note).slice(0, 400) : null,
    tv: p.tv || null,
  };
}

// ── Execution ─────────────────────────────────────────────────────────────────

async function executeAndReport(env, plan) {
  try {
    const result = plan.venue === 'kraken'
      ? await executeKraken(env, plan)
      : await executeAlpaca(env, plan);

    await ruleCall(env, plan.ruleId, '/settle', {
      fireId: plan.fireId, status: 'executed', detail: result.description || null,
    });
    await notify(env, successMessage(plan, result));
  } catch (e) {
    // Distinguish "the venue said no" from "we never reached the venue". Only
    // the latter re-arms a one-shot rule — see RuleState.settle.
    const transport = /fetch failed|network|timeout|not configured/i.test(e.message);
    await ruleCall(env, plan.ruleId, '/settle', {
      fireId: plan.fireId,
      status: transport ? 'transport_failed' : 'rejected',
      detail: e.message,
    });
    await notify(env, failureMessage(plan, e, transport));
  }
}

// Kraken spot is 24/7 — no session routing, no extended-hours branch.
export async function executeKraken(env, plan) {
  if (plan.action === 'cancel') {
    if (plan.dryRun) return { venue: 'kraken', dryRun: true, orderIds: [], description: `DRY RUN — would cancel open ${plan.pair} orders` };
    return kraken.cancelOpenOrders(env, plan.pair);
  }

  const q = await kraken.quote(plan.pair);
  const side = ENTRY_ACTIONS.has(plan.action) ? 'buy' : 'sell';
  const ordertype = plan.urgency === 'patient' ? 'limit' : 'market';
  const price = ordertype === 'limit'
    ? plan.limitPrice
    : null;

  guardSlippage(plan, q, side);

  let volume;
  if (plan.action === 'close') {
    volume = await kraken.assetBalance(env, plan.asset);
    if (!volume) throw new Error(`no ${plan.asset} balance on Kraken to close`);
  } else if (plan.size.qty != null) {
    volume = plan.size.qty;
  } else if (plan.size.usd != null) {
    volume = plan.size.usd / (price || q.last);
  } else {
    const bal = await kraken.assetBalance(env, plan.asset);
    if (!bal) throw new Error(`no ${plan.asset} balance on Kraken to trim`);
    volume = bal * (plan.size.pct / 100);
  }

  return kraken.placeOrder(env, {
    pair: plan.pair, side, ordertype,
    volume: round(volume, 8),
    price: price != null ? round(price, 6) : undefined,
    dryRun: plan.dryRun,
  });
}

/**
 * Equities. This is where the session router earns its keep: an order that is
 * correct at 15:59 is rejected at 16:01, so session is re-read at EXECUTION
 * time, never at trigger time.
 */
export async function executeAlpaca(env, plan) {
  if (plan.action === 'cancel') {
    if (plan.dryRun) return { venue: 'alpaca', dryRun: true, orderIds: [], description: `DRY RUN — would cancel open ${plan.symbol} orders` };
    return alpaca.cancelOpenOrders(env, plan.symbol);
  }

  const { status } = await alpaca.marketStatus(env);

  if (status === 'closed' && plan.whenClosed === 'abort') {
    throw new Error('market closed and when_closed="abort"');
  }

  const side = ENTRY_ACTIONS.has(plan.action) ? 'buy' : 'sell';
  const extended = status === 'pre' || status === 'post';
  const isExit = plan.action === 'close' || plan.action === 'trim';

  // Order-type selection, mirroring the MarketStatus branch in ARCHITECTURE.md:
  //   open           → market (fastest fill)
  //   pre/post       → limit at the touch, extended_hours=true (Alpaca rejects
  //                    market orders outside RTH)
  //   closed + queue → limit day order; rests until the next open
  let type, limitPrice = null;
  const timeInForce = 'day';
  if (status === 'open' && plan.urgency === 'fast') {
    type = 'market';
  } else {
    type = 'limit';
    if (plan.limitPrice != null) {
      limitPrice = plan.limitPrice;
    } else {
      const q = await alpaca.quote(env, plan.symbol);
      // Sell at the best bid, buy at the best ask — cross the spread to fill now
      // rather than resting behind it.
      limitPrice = side === 'sell' ? q.bid : q.ask;
      if (!limitPrice) throw new Error(`no ${side === 'sell' ? 'bid' : 'ask'} available for ${plan.symbol}`);
      guardSlippage(plan, q, side);
    }
  }

  // Server-side sizing via close-position cannot race a position that is
  // changing underneath us, so prefer it — but ONLY when it can express what we
  // actually mean. It takes percentage or qty, so a usd-denominated trim has to
  // go the explicit route, and it always emits a market order, so it is unusable
  // outside regular hours.
  const canUseClosePosition =
    isExit && type === 'market' && (plan.action === 'close' || plan.size.pct != null || plan.size.qty != null);

  if (canUseClosePosition) {
    const args = { symbol: plan.symbol };
    if (plan.action === 'close')        args.percentage = 100;
    else if (plan.size.pct != null)     args.percentage = plan.size.pct;
    else                                args.qty = plan.size.qty;

    if (plan.dryRun) {
      return {
        venue: 'alpaca', dryRun: true, orderIds: [],
        description: `DRY RUN — would ${args.percentage != null ? 'close ' + args.percentage + '% of' : 'sell ' + args.qty} ${plan.symbol} at market`,
      };
    }
    return alpaca.closePosition(env, args);
  }

  // Explicit-order path: resolve an absolute quantity first.
  let qty = null, notional = null;
  if (isExit) {
    const pos = await alpaca.position(env, plan.symbol);
    if (!pos) throw new Error(`no open ${plan.symbol} position at Alpaca`);
    const held = Math.abs(parseFloat(pos.qty));
    if (plan.action === 'close')     qty = held;
    else if (plan.size.qty != null)  qty = Math.min(plan.size.qty, held);
    else if (plan.size.pct != null)  qty = held * (plan.size.pct / 100);
    else                             qty = Math.min(plan.size.usd / (limitPrice || 1), held);
    qty = Math.floor(qty * 1e6) / 1e6;
    if (qty <= 0) throw new Error(`computed sell quantity for ${plan.symbol} was zero`);
  } else if (plan.size.qty != null) {
    qty = plan.size.qty;
  } else {
    // notional is market-order-only at Alpaca; a limit order must carry a qty.
    if (type === 'limit') qty = Math.floor((plan.size.usd / limitPrice) * 1e6) / 1e6;
    else notional = plan.size.usd;
  }

  if (plan.dryRun) {
    return {
      venue: 'alpaca', dryRun: true, orderIds: [],
      description: `DRY RUN — would ${side} ${qty != null ? qty : '$' + notional} ${plan.symbol} ${type}` +
                   `${limitPrice ? ' @ ' + round(limitPrice, 4) : ''}${extended ? ' (ext hours)' : ''}`,
    };
  }

  return alpaca.placeOrder(env, {
    symbol: plan.symbol, side, type, qty, notional,
    limitPrice: limitPrice != null ? round(limitPrice, 4) : null,
    extendedHours: extended,
    timeInForce,
    // Alpaca rejects a duplicate client_order_id — a genuine second line of
    // defence behind the Durable Object claim.
    clientOrderId: `tv-${plan.fireId}`.slice(0, 48).replace(/[^\w-]/g, '-'),
  });
}

/**
 * Refuse to trade into a spread wider than the rule tolerates. "As fast as
 * possible" and "at a sane price" pull against each other; this is the dial.
 */
function guardSlippage(plan, q, side) {
  if (plan.maxSlippagePct == null) return;
  const bid = q.bid, ask = q.ask;
  if (!bid || !ask) return;
  const mid = (bid + ask) / 2;
  const spreadPct = ((ask - bid) / mid) * 100;
  if (spreadPct > plan.maxSlippagePct) {
    throw new Error(
      `spread ${spreadPct.toFixed(2)}% exceeds max_slippage_pct ${plan.maxSlippagePct}% ` +
      `(bid ${bid} / ask ${ask}) — refusing to ${side}`,
    );
  }
}

// ── Notifications ─────────────────────────────────────────────────────────────

function pendingMessage(plan) {
  return [
    `🟡 *TradingView alert — confirmation needed*`,
    ``,
    `*${escapeMd(plan.action.toUpperCase())} ${escapeMd(plan.symbol)}* on ${plan.venue}`,
    `Size: ${escapeMd(describeSize(plan))}`,
    plan.note ? `Note: ${escapeMd(plan.note)}` : null,
    ``,
    `Reply \`go ${escapeMd(plan.ruleId)}\` to execute, or \`deny ${escapeMd(plan.ruleId)}\` to skip.`,
    `_Expires in 1 hour._`,
  ].filter(Boolean).join('\n');
}

function successMessage(plan, result) {
  const tag = result.dryRun ? '🧪 *DRY RUN*' : (result.live === false ? '📝 *PAPER*' : '✅ *Order placed*');
  return [
    `${tag} — ${escapeMd(plan.symbol)}`,
    ``,
    `${escapeMd(plan.action)} on ${plan.venue}${plan.venue === 'alpaca' && result.live === false ? ' (paper)' : ''}`,
    `Size: ${escapeMd(describeSize(plan))}`,
    result.description ? `Detail: ${escapeMd(result.description)}` : null,
    result.orderIds?.length ? `Order: \`${escapeMd(result.orderIds.join(', '))}\`` : null,
    plan.note ? `Why: ${escapeMd(plan.note)}` : null,
    ``,
    `Rule: \`${escapeMd(plan.ruleId)}\``,
  ].filter(Boolean).join('\n');
}

function failureMessage(plan, err, transport) {
  return [
    `🔴 *Order FAILED* — ${escapeMd(plan.symbol)}`,
    ``,
    `${escapeMd(plan.action)} on ${plan.venue}`,
    `Size: ${escapeMd(describeSize(plan))}`,
    `Error: ${escapeMd(err.message)}`,
    ``,
    transport
      ? `_Never reached the venue — rule re-armed, it can fire again._`
      : `_The venue rejected this. Rule stays spent; re-arm manually if you want a retry._`,
    `Rule: \`${escapeMd(plan.ruleId)}\``,
  ].join('\n');
}

function describeSize(plan) {
  if (plan.action === 'close') return 'entire position';
  if (plan.action === 'cancel') return 'open orders';
  if (plan.size.pct != null) return `${plan.size.pct}% of position`;
  if (plan.size.usd != null) return `$${plan.size.usd}`;
  return `${plan.size.qty} units`;
}

/**
 * Deliberately duplicated from src/index.js rather than refactored out of it:
 * the Telegram path in index.js is live and working, and this feature should
 * not be able to break it. Small duplication, zero blast radius.
 */
async function notify(env, text) {
  if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) return;
  try {
    await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: env.TELEGRAM_CHAT_ID, text, parse_mode: 'Markdown',
      }),
    });
  } catch { /* notification failure must never mask a trade result */ }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

function round(n, dp) { return Number(Number(n).toFixed(dp)); }
function text(status, body) { return new Response(body, { status }); }
function json(obj) { return new Response(JSON.stringify(obj, null, 2), { headers: { 'Content-Type': 'application/json' } }); }
function escapeMd(s) { return String(s).replace(/([_*`\[\]])/g, '\\$1'); }

function safeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
