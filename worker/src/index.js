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
  '1336082716063694962': { trader: 'Crypto_Chase',  type: 'primary' },
  '1343971265962049597': { trader: 'Crypto_Chase',  type: 'supporting' },
  '1247927786681794601': { trader: 'Crypto_Chase',  type: 'supporting' },
  '1411492188315193416': { trader: 'KillaXBT',      type: 'primary' },
  '1472153627324842057': { trader: 'HeartCanHodl',  type: 'primary' },
  '1191800982414299217': { trader: 'HeartCanHodl',  type: 'primary' },
  '1279738718680256553': { trader: 'HeartCanHodl',  type: 'primary' },   // most important
  '1393137051108507728': { trader: 'HeartCanHodl',  type: 'primary' },
  '1023638573313966212': { trader: 'HeartCanHodl',  type: 'supporting' },
};

const WATCHED_DISCORD_USERNAMES = new Set(['crypto_chase', 'killaxbt', 'heartcanhodl']);
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

  const username = tweet.screen_name ?? tweet?.author?.username ?? 'unknown';
  const text     = tweet.text ?? '';
  const tweetId  = tweet.id ?? '';

  if (!text.trim()) return new Response('OK');

  const tweetUrl = `https://x.com/${username}/status/${tweetId}`;

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

// ── Discord poller (cron every 1 min) ─────────────────────────────────────────

async function pollDiscord(env) {
  const channelIds = Object.keys(CHANNEL_CONFIG);

  for (const channelId of channelIds) {
    try {
      const lastSeenKey = `discord_last_${channelId}`;
      const lastSeenId  = await env.BOT_STATE.get(lastSeenKey);

      // Fetch messages after last seen (or last 10 if first run)
      let apiUrl = `https://discord.com/api/v10/channels/${channelId}/messages?limit=10`;
      if (lastSeenId) apiUrl += `&after=${lastSeenId}`;

      const resp = await fetch(apiUrl, {
        headers: {
          Authorization:   env.DISCORD_USER_TOKEN,
          'Content-Type':  'application/json',
        },
      });

      if (!resp.ok) continue;

      const messages = await resp.json();
      if (!Array.isArray(messages) || messages.length === 0) continue;

      // Sort oldest → newest (Discord returns newest first)
      messages.sort((a, b) => (BigInt(a.id) < BigInt(b.id) ? -1 : 1));

      // Update last seen to newest message ID
      const newestId = messages[messages.length - 1].id;
      await env.BOT_STATE.put(lastSeenKey, newestId);

      // Process trader messages only
      for (const msg of messages) {
        const authorUsername = msg?.author?.username?.toLowerCase() ?? '';
        if (!WATCHED_DISCORD_USERNAMES.has(authorUsername)) continue;

        const content     = msg.content?.trim() ?? '';
        const attachments = (msg.attachments ?? []).map((a) => a?.url).filter(Boolean);
        if (!content && attachments.length === 0) continue;

        // No raw forward to Telegram — discord-trader-monitor is the sole gate
        // on what reaches Kyle. Pass the event through as base64-JSON via
        // ${var}; the skill resolves channel hierarchy, reply context, and
        // classification, then decides whether (and how) to alert.
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
    try {
      await fetch(
        `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ chat_id: chatId, text: chunk, parse_mode: 'Markdown' }),
        }
      );
    } catch (e) {
      // Retry without markdown if parse fails
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
  const repo  = env.GH_REPO;
  const base  = `https://raw.githubusercontent.com/${repo}/main`;
  const today = new Date().toISOString().slice(0, 10);

  console.log(`answerFreeform: start, msg="${userMessage.slice(0,50)}"`);

  // Fetch memory context in parallel — public repo, no auth needed
  const [traders, activeTrades, tickerFocus, todayLog] = await Promise.allSettled([
    fetchText(`${base}/memory/topics/traders.md`),
    fetchText(`${base}/memory/topics/active-trades.md`),
    fetchText(`${base}/memory/topics/ticker-focus.md`),
    fetchText(`${base}/memory/logs/${today}.md`),
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
    console.error('answerFreeform error:', e.message);
    reply = `⚠️ Could not reach Claude (${e.message}). Try again or send "status".`;
  }

  await sendTelegram(env, chatId, reply);
  console.log('answerFreeform: done');
}

async function fetchText(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.text();
}
