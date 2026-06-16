/**
 * Trading Bot — Cloudflare Worker
 *
 * Handles:
 *   POST /telegram  — Telegram webhook (instant command routing)
 *   POST /twitter   — twitterapi.io webhook → relays event to x-trader-monitor
 *   Cron every 1min — Discord polling → relays each event to discord-trader-monitor
 *
 * Note: the Worker does NOT forward raw X/Discord content to Telegram. Each
 * event is base64-JSON-encoded and handed to AEON via `${var}` (toBase64Json),
 * and the monitor skill is the SOLE gate on what reaches Kyle — this avoids
 * double-alerting (raw forward + classified alert for the same event).
 *
 * Env secrets (set via wrangler secret put):
 *   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
 *   DISCORD_USER_TOKEN
 *   GH_TOKEN, GH_REPO
 *   ANTHROPIC_API_KEY
 *
 * KV namespace: BOT_STATE (stores Discord last-seen message IDs)
 */

// ── Channel config ────────────────────────────────────────────────────────────

const CHANNEL_CONFIG = {
  '1336082716063694962': { trader: 'Crypto_Chase',  type: 'primary',    label: 'Chase — Chase' },
  '1343971265962049597': { trader: 'Crypto_Chase',  type: 'supporting', label: 'Chase — TradFi' },
  '1247927786681794601': { trader: 'Crypto_Chase',  type: 'supporting', label: 'Chase — Crypto' },
  '1411492188315193416': { trader: 'KillaXBT',      type: 'primary',    label: 'K' },
  '1472153627324842057': { trader: 'HeartCanHodl',  type: 'primary',    label: 'HCH — Free' },
  '1191800982414299217': { trader: 'HeartCanHodl',  type: 'primary',    label: 'HCH — Opportunistic Moments' },
  '1279738718680256553': { trader: 'HeartCanHodl',  type: 'primary',    label: 'HCH — Trades' },  // most important; verbatim rule
  '1393137051108507728': { trader: 'HeartCanHodl',  type: 'primary',    label: 'HCH — Comments' },
  '1023638573313966212': { trader: 'HeartCanHodl',  type: 'supporting', label: 'HCH — Chat' },
};

const WATCHED_DISCORD_USERNAMES = new Set(['crypto_chase', 'killaxbt', 'heartcanhodl']);
const WATCHED_X_USERNAMES = new Set([
  'crypto_chase', 'killaxbt', 'heartcanhodl', 'bitcoin_astro',
  'abetrade', 'trading_axe', 't_in_crypto', 'ryzzqq',
  'swarmister', 'bull_genius', 'stoiiic', 'wild_randomness',
]);
// Ignored accounts: Banana3Stocks, benjamincowen

// ── Entry point ───────────────────────────────────────────────────────────────

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/telegram') {
      return handleTelegram(request, env, ctx);
    }
    if (request.method === 'POST' && url.pathname === '/twitter') {
      return handleTwitter(request, env, ctx);
    }

    return new Response('Trading Bot — OK', { status: 200 });
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(pollDiscord(env));
  },
};

// ── Telegram handler ──────────────────────────────────────────────────────────

async function handleTelegram(request, env, ctx) {
  let body;
  try { body = await request.json(); } catch { return new Response('OK'); }

  const message = body?.message;
  if (!message) return new Response('OK');

  const rawText = message?.text?.trim() ?? '';
  const text    = rawText.toLowerCase();
  const chatId  = String(message?.chat?.id ?? env.TELEGRAM_CHAT_ID);

  if (!text) return new Response('OK');

  // ── Command routing ────────────────────────────────────────────────────────
  if (text === 'brief') {
    await sendTelegram(env, chatId, '⏳ Generating trading brief...');
    ctx.waitUntil(triggerAEON(env, 'trading-brief'));

  } else if (text.startsWith('close trade')) {
    const detail = rawText.slice('close trade'.length).trim();
    await sendTelegram(env, chatId, `⏳ Closing trade: ${detail}`);
    ctx.waitUntil(triggerAEON(env, 'close-trade', detail));

  } else if (text === 'status') {
    ctx.waitUntil(triggerAEON(env, 'heartbeat'));
    await sendTelegram(env, chatId, '⏳ Checking system status...');

  } else if (text.startsWith('approve')) {
    const detail = rawText.slice('approve'.length).trim();
    await sendTelegram(env, chatId, `✅ Approved. What is your USD size for this trade?`);
    await env.BOT_STATE.put(`pending_trade_${chatId}`, detail, { expirationTtl: 3600 });

  } else if (text.startsWith('confirm')) {
    const pendingTrade = await env.BOT_STATE.get(`pending_trade_${chatId}`);
    if (pendingTrade) {
      const detail = rawText.slice('confirm'.length).trim();
      await sendTelegram(env, chatId, `⏳ Executing trade on Kraken...`);
      ctx.waitUntil(triggerAEON(env, 'kraken-execute', `${pendingTrade} | size: ${detail}`));
      await env.BOT_STATE.delete(`pending_trade_${chatId}`);
    } else {
      await sendTelegram(env, chatId, `No pending trade to confirm.`);
    }

  } else if (/^chart\s+\$?[a-z0-9]+/i.test(text)) {
    // Chart request — dispatch chart-request skill with full command as var
    await sendTelegram(env, chatId, '⏳ Fetching chart...');
    ctx.waitUntil(triggerAEON(env, 'chart-request', rawText));

  } else {
    // Freeform — answer directly via Claude API (2-8s) if key is set,
    // otherwise fall back to AEON concierge via GitHub Actions (~2min).
    await sendTelegram(env, chatId, '⏳ On it...');
    if (env.ANTHROPIC_API_KEY) {
      ctx.waitUntil(answerFreeform(env, chatId, rawText));
    } else {
      ctx.waitUntil(triggerAEON(env, 'concierge', rawText));
    }
  }

  return new Response('OK');
}

// ── twitterapi.io webhook handler ─────────────────────────────────────────────

async function handleTwitter(request, env, ctx) {
  let body;
  try { body = await request.json(); } catch { return new Response('OK'); }

  const eventType = body?.event_type;
  if (!eventType || eventType === 'ping' || eventType === 'connected') {
    return new Response('OK');
  }

  // fast_tweet and tweet both carry the tweet at body.tweet; tweets[] is a
  // batch format twitterapi.io occasionally uses — fall back to body.tweet.
  const tweet = body?.tweet ?? body?.tweets?.[0];

  if (!tweet) return new Response('OK');

  const username = tweet.screen_name ?? tweet?.user?.screen_name ?? tweet?.user?.username ?? tweet?.author?.username ?? tweet?.author?.screen_name ?? 'unknown';
  const text     = tweet.text ?? '';
  const tweetId  = tweet.id ?? '';

  if (!text.trim()) return new Response('OK');

  const tweetUrl = `https://x.com/${username}/status/${tweetId}`;

  if (!WATCHED_X_USERNAMES.has(username.toLowerCase())) return new Response('OK');

  // No raw forward to Telegram — x-trader-monitor is the sole gate on what
  // reaches Kyle. Pass the event through as base64-JSON via ${var}; the skill
  // decides whether (and how) to alert.
  const event = {
    id:         tweetId,
    username,
    text,
    created_at: tweet.created_at ?? tweet?.tweet_created_at ?? '',
    url:        tweetUrl,
    media:      extractTweetMedia(tweet),
  };

  ctx.waitUntil(triggerAEON(env, 'x-trader-monitor', toBase64Json(event)));

  return new Response('OK');
}

function extractTweetMedia(tweet) {
  const entities = tweet?.extended_entities?.media ?? tweet?.entities?.media ?? [];
  if (!Array.isArray(entities)) return [];
  return entities
    .map((m) => m?.media_url_https ?? m?.media_url ?? null)
    .filter(Boolean);
}

// ── Discord fast-path classifier ──────────────────────────────────────────────
// Calls Claude Haiku directly to classify and alert in ~2-5s.
// Returns true if a Telegram alert was sent, false otherwise.
// The result is passed as fast_path_alerted in the AEON event so the skill
// skips re-alerting but still does memory updates and logging.

async function classifyAndAlertDiscord(env, event) {
  if (!env.ANTHROPIC_API_KEY) return false;

  const ch = CHANNEL_CONFIG[event.channel_id] ?? {};
  const label       = ch.label ?? ch.trader ?? event.username;
  const channelType = ch.type ?? 'primary';
  const isVerbatim  = event.channel_id === '1279738718680256553'; // HCH — Trades

  const replyCtx = event.is_reply && event.referenced_message
    ? `\nReplying to ${event.referenced_message.username}: "${event.referenced_message.content}"`
    : '';
  const attachNote = event.attachments?.length
    ? `\n[${event.attachments.length} attachment(s)]`
    : '';

  const prompt =
`Discord message from ${ch.trader ?? event.username} in "${label}" (${channelType} channel):${replyCtx}
"${event.content}"${attachNote}

Classify as SIGNAL or NOISE.
SIGNAL: directional call, price target, stop/invalidation, position change, conviction shift, actionable market view.
NOISE: admin, scheduling, links, banter, motivation without trade detail, test messages.
For supporting channels: only SIGNAL if it's a clear, self-contained conviction shift — not chatter.

If SIGNAL, write a short Telegram alert (under 400 chars total). Keep the trader's message verbatim in the body.${isVerbatim ? ' VERBATIM CHANNEL — never rephrase or expand the body.' : ''}
Format:
- Trade/position action → 🚨 *[DC: ${label}]*\\n\\n{message_text}
- Analysis/informational → 💬 *[DC: ${label}]*\\n\\n{message_text}
- If reply context matters, prepend: ↩️ _Member: "{reply_text}"_\\n\\n

Respond with JSON only: {"is_signal":true|false,"alert_text":"..."|null}`;

  try {
    const controller = new AbortController();
    const timeoutId  = setTimeout(() => controller.abort(), 8000);

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key':         env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type':      'application/json',
      },
      body: JSON.stringify({
        model:      'claude-haiku-4-5-20251001',
        max_tokens: 300,
        system:     'You are a trading signal classifier. Output only valid JSON. No preamble or explanation.',
        messages:   [{ role: 'user', content: prompt }],
      }),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!resp.ok) {
      console.error(`classifyAndAlertDiscord: Claude API ${resp.status}`);
      return false;
    }

    const data    = await resp.json();
    const rawText = data?.content?.[0]?.text?.trim() ?? '';
    // Strip markdown fences if model wrapped the JSON
    const jsonText = rawText.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '');
    const result  = JSON.parse(jsonText);

    if (result.is_signal && result.alert_text) {
      await sendTelegram(env, env.TELEGRAM_CHAT_ID, result.alert_text);
      console.log(`classifyAndAlertDiscord: alerted — ${ch.trader} in ${label}`);
      return true;
    }

    return false;
  } catch (e) {
    console.error('classifyAndAlertDiscord error:', e.message);
    return false;
  }
}

// ── Discord poller (cron every 1 min) ─────────────────────────────────────────

async function pollDiscord(env) {
  const channelIds = Object.keys(CHANNEL_CONFIG);

  // Hard subrequest budget — CF limit is 50/invocation.
  // Each operation deducts from the budget; we stop before hitting the ceiling.
  // Accounting:
  //   Channel baseline: 2 (KV get + Discord fetch) + 1 if new messages (KV put)
  //   Per trader message: 3 (Claude API + Telegram send + GitHub dispatch)
  // Budget of 44 leaves a 6-slot safety buffer and covers all 9 channels
  // at baseline (18 slots) + ~8 concurrent trader messages before stopping.
  let budget = 44;
  const spend = (n = 1) => { budget -= n; };

  for (const channelId of channelIds) {
    if (budget < 2) {
      console.log(`pollDiscord: budget exhausted, skipping remaining channels`);
      break;
    }

    try {
      const lastSeenKey = `discord_last_${channelId}`;
      const lastSeenId  = await env.BOT_STATE.get(lastSeenKey);
      spend(); // KV get

      let apiUrl = `https://discord.com/api/v10/channels/${channelId}/messages?limit=10`;
      if (lastSeenId) apiUrl += `&after=${lastSeenId}`;

      const resp = await fetch(apiUrl, {
        headers: {
          Authorization:   env.DISCORD_USER_TOKEN,
          'Content-Type':  'application/json',
        },
      });
      spend(); // Discord fetch

      if (!resp.ok) continue;

      const messages = await resp.json();
      if (!Array.isArray(messages) || messages.length === 0) continue;

      // Sort oldest → newest (Discord returns newest first)
      messages.sort((a, b) => (BigInt(a.id) < BigInt(b.id) ? -1 : 1));

      // Update last seen to newest message ID
      const newestId = messages[messages.length - 1].id;
      await env.BOT_STATE.put(lastSeenKey, newestId);
      spend(); // KV put

      // Process trader messages only
      for (const msg of messages) {
        const authorUsername = msg?.author?.username?.toLowerCase() ?? '';
        if (!WATCHED_DISCORD_USERNAMES.has(authorUsername)) continue;

        const content     = msg.content?.trim() ?? '';
        const attachments = (msg.attachments ?? []).map((a) => a?.url).filter(Boolean);
        if (!content && attachments.length === 0) continue;

        // Reserve 3 slots upfront (Claude + Telegram + GitHub) before processing.
        // Conservative: deduct the max cost regardless of whether it ends up a signal.
        if (budget < 3) {
          console.log(`pollDiscord: budget exhausted at channel ${channelId}, msg ${msg.id}`);
          break;
        }
        spend(3);

        const ref = msg.referenced_message;
        const referencedMessage = ref
          ? { username: ref?.author?.username ?? 'member', content: (ref?.content ?? '').slice(0, 150) }
          : null;

        const event = {
          id:                  msg.id,
          channel_id:          channelId,
          username:            authorUsername,
          content,
          created_at:          msg.timestamp ?? '',
          is_reply:            Boolean(ref),
          referenced_message:  referencedMessage,
          attachments,
        };

        const fastPathAlerted       = await classifyAndAlertDiscord(env, event);
        event.fast_path_alerted     = fastPathAlerted;

        await triggerAEON(env, 'discord-trader-monitor', toBase64Json(event));
      }

    } catch (e) {
      console.error(`Discord poll error for channel ${channelId}:`, e.message);
    }

    // Small delay to avoid Discord rate limits
    await sleep(300);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Base64-encode a JSON-serializable event for the `${var}` pass-through to
// x-trader-monitor / discord-trader-monitor. Goes through TextEncoder first so
// unicode (emoji, non-Latin trader text, etc.) survives — btoa() alone chokes
// on anything outside Latin1.
function toBase64Json(obj) {
  const bytes = new TextEncoder().encode(JSON.stringify(obj));
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

async function triggerAEON(env, skill, varValue = '') {
  const url = `https://api.github.com/repos/${env.GH_REPO}/actions/workflows/aeon.yml/dispatches`;
  console.log(`triggerAEON: skill=${skill} repo=${env.GH_REPO} var_len=${varValue.length}`);
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization:  `Bearer ${env.GH_TOKEN}`,
      Accept:         'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent':   'trading-bot-worker/1.0',
    },
    body: JSON.stringify({ ref: 'main', inputs: { skill, var: varValue } }),
  });
  const body = resp.ok ? '' : await resp.text();
  console.log(`triggerAEON: skill=${skill} status=${resp.status} body=${body.slice(0,200)}`);
  return resp.ok;
}

async function sendTelegram(env, chatId, text) {
  const MAX = 3900;
  const chunks = [];
  for (let i = 0; i < text.length; i += MAX) chunks.push(text.slice(i, i + MAX));

  for (const chunk of chunks) {
    const resp = await fetch(
      `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: chatId, text: chunk, parse_mode: 'Markdown' }),
      }
    );
    if (!resp.ok) {
      // Retry without markdown — Telegram returns 400 on malformed entities, fetch won't throw
      await fetch(
        `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ chat_id: chatId, text: chunk }),
        }
      );
    }
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── Direct Claude freeform handler ────────────────────────────────────────────

async function answerFreeform(env, chatId, userMessage) {
  try {
    await _answerFreeform(env, chatId, userMessage);
  } catch (e) {
    console.error('answerFreeform outer:', e.message);
    const isTimeout = e.name === 'AbortError';
    const msg = isTimeout
      ? '⚠️ Timed out — took too long to think. Try again or rephrase.'
      : `⚠️ Something went wrong (${e.message.slice(0, 120)}). Try again or send "status".`;
    try {
      await sendTelegram(env, chatId, msg);
    } catch (telegramErr) {
      console.error('answerFreeform: failed to send error to Telegram:', telegramErr.message);
    }
  }
}

async function _answerFreeform(env, chatId, userMessage) {
  const repo  = env.GH_REPO;
  const base  = `https://raw.githubusercontent.com/${repo}/main`;
  const today = new Date().toISOString().slice(0, 10);

  const controller = new AbortController();
  const timeoutId  = setTimeout(() => controller.abort(), 20000);

  console.log(`answerFreeform: start, msg="${userMessage.slice(0,50)}"`);

  // Fetch memory context in parallel — public repo, no auth needed
  const [traders, activeTrades, tickerFocus, todayLog] = await Promise.allSettled([
    fetchText(`${base}/memory/topics/traders.md`, controller.signal),
    fetchText(`${base}/memory/topics/active-trades.md`, controller.signal),
    fetchText(`${base}/memory/topics/ticker-focus.md`, controller.signal),
    fetchText(`${base}/memory/logs/${today}.md`, controller.signal),
  ]);

  console.log(`answerFreeform: memory fetched — traders=${traders.status} activeTrades=${activeTrades.status} tickerFocus=${tickerFocus.status} log=${todayLog.status}`);

  const sections = [
    traders.status      === 'fulfilled' ? `## traders.md\n${traders.value}`           : '',
    activeTrades.status === 'fulfilled' ? `## active-trades.md\n${activeTrades.value}` : '',
    tickerFocus.status  === 'fulfilled' ? `## ticker-focus.md\n${tickerFocus.value}`   : '',
    todayLog.status     === 'fulfilled' ? `## today's log (${today})\n${todayLog.value}` : '',
  ].filter(Boolean).join('\n\n---\n\n');

  console.log(`answerFreeform: context built, ~${sections.length} chars — calling Claude`);

  const system = `You are AEON, a trading bot assistant. Today is ${today}.
Kyle runs a crypto/stocks trading bot monitoring 12 traders on X and Discord.
Answer his Telegram messages directly and concisely — informal and direct, match his tone.
Cite specific traders by name when referencing their views. If he asks for live prices you don't have them — say so plainly.

Current bot state:
${sections}`;

  let reply;
  try {
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key':         env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type':      'application/json',
      },
      body: JSON.stringify({
        model:      'claude-haiku-4-5-20251001',
        max_tokens: 1024,
        system,
        messages:   [{ role: 'user', content: userMessage }],
      }),
      signal: controller.signal,
    });

    console.log(`answerFreeform: Claude responded ${resp.status}`);

    if (!resp.ok) {
      const errBody = await resp.text();
      throw new Error(`Claude API ${resp.status}: ${errBody.slice(0, 300)}`);
    }
    const data = await resp.json();
    reply = data?.content?.[0]?.text ?? '(empty response)';
    console.log(`answerFreeform: reply ready, ~${reply.length} chars — sending Telegram`);
  } catch (e) {
    if (e.name === 'AbortError') throw e; // propagate to outer handler for clean timeout message
    console.error('answerFreeform error:', e.message);
    reply = `⚠️ Could not reach Claude (${e.message}). Try again or send "status".`;
  } finally {
    clearTimeout(timeoutId);
  }

  await sendTelegram(env, chatId, reply);
  console.log('answerFreeform: done');
}

async function fetchText(url, signal) {
  const r = await fetch(url, signal ? { signal } : undefined);
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.text();
}
