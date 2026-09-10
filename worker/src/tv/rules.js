/**
 * RuleState — Durable Object holding the fire-state of every TradingView rule.
 *
 * WHY A DURABLE OBJECT AND NOT KV
 * KV has no compare-and-set and is eventually consistent. Two webhook
 * deliveries arriving concurrently would both read `armed: true` and both fire —
 * a double-sell. TradingView webhook delivery is explicitly at-least-once, so
 * this is not a hypothetical. A Durable Object serialises all requests for a
 * given rule id through a single thread, which makes "claim exactly once" a
 * real guarantee rather than a hopeful one.
 *
 * This object is the ONLY authority on whether a rule may fire. Every execution
 * path must claim here first and must not proceed on a rejected claim.
 */

export class RuleState {
  constructor(state) {
    this.state = state;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const body = request.method === 'POST' ? await request.json().catch(() => ({})) : {};

    switch (url.pathname) {
      case '/claim':   return json(await this.claim(body));
      case '/settle':  return json(await this.settle(body));
      case '/state':   return json(await this.read());
      case '/rearm':   return json(await this.rearm(body));
      default:         return new Response('Not found', { status: 404 });
    }
  }

  async read() {
    return (await this.state.storage.get('rule')) || {
      fires: 0, armed: true, lastFireAt: 0, lastFireId: null, history: [],
    };
  }

  /**
   * Attempt to take the single fire-slot for this rule.
   *
   * Rejects — and says why — when:
   *   - the same fireId already claimed (duplicate webhook delivery)
   *   - the rule is disarmed (one-shot already spent)
   *   - we are inside the cooldown window
   *   - maxFires is exhausted
   */
  async claim({ fireId, cooldownSec = 60, maxFires = null, oneShot = false, meta = {} }) {
    const rule = await this.read();
    const now = Date.now();

    if (fireId && rule.history.some((h) => h.fireId === fireId)) {
      return { ok: false, reason: 'duplicate_fire_id', rule };
    }
    if (!rule.armed) {
      return { ok: false, reason: 'disarmed', rule };
    }
    if (maxFires != null && rule.fires >= maxFires) {
      return { ok: false, reason: 'max_fires_reached', rule };
    }
    const sinceLast = (now - rule.lastFireAt) / 1000;
    if (rule.lastFireAt && sinceLast < cooldownSec) {
      return { ok: false, reason: 'cooldown', cooldownRemainingSec: Math.ceil(cooldownSec - sinceLast), rule };
    }

    rule.fires += 1;
    rule.lastFireAt = now;
    rule.lastFireId = fireId || null;
    if (oneShot) rule.armed = false;
    rule.history.unshift({ fireId, at: now, status: 'claimed', meta });
    rule.history = rule.history.slice(0, 25);

    await this.state.storage.put('rule', rule);
    return { ok: true, rule };
  }

  /**
   * Record what actually happened to a claimed fire.
   *
   * A failed execution re-arms a one-shot rule: the claim was spent on an order
   * that never reached the venue, so holding the rule disarmed would silently
   * drop the trade. A *rejected* order (venue said no) is still a real outcome
   * and does not re-arm — only transport/credential failures do.
   */
  async settle({ fireId, status, detail = null, rearmOnFailure = true }) {
    const rule = await this.read();
    const entry = rule.history.find((h) => h.fireId === fireId);
    if (entry) {
      entry.status = status;
      entry.detail = detail;
      entry.settledAt = Date.now();
    }
    if (status === 'transport_failed' && rearmOnFailure) {
      rule.armed = true;
      rule.fires = Math.max(0, rule.fires - 1);
      rule.lastFireAt = 0;
    }
    await this.state.storage.put('rule', rule);
    return { ok: true, rule };
  }

  /** Manual re-arm, for a one-shot rule you want to reuse. */
  async rearm({ resetFires = false }) {
    const rule = await this.read();
    rule.armed = true;
    rule.lastFireAt = 0;
    if (resetFires) rule.fires = 0;
    await this.state.storage.put('rule', rule);
    return { ok: true, rule };
  }
}

function json(obj) {
  return new Response(JSON.stringify(obj), {
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Helper for callers: get the DO stub for a rule id. */
export function ruleStub(env, ruleId) {
  return env.RULE_STATE.get(env.RULE_STATE.idFromName(`tv-rule:${ruleId}`));
}

export async function ruleCall(env, ruleId, path, body) {
  const resp = await ruleStub(env, ruleId).fetch(`https://rule${path}`, {
    method: 'POST',
    body: JSON.stringify(body || {}),
    headers: { 'Content-Type': 'application/json' },
  });
  return resp.json();
}
